package hostdb

import (
	"fmt"
	"net/http"
	"errors"
	"net/url"
	"strings"
	"io/ioutil"
	"bytes"
)

const (
	proto = "https"
	version = "v1"
)

var UnknownLength = errors.New("length of http response is unknown")
var InvalidParams = errors.New("parameters are invalid/missing")
var RequestFailed = errors.New("Request failed")
var LastResponse http.Response

type Config struct {
	User string
	Password string
	Session string
	Server string
}

type httpStatus struct {
	Code int
	Message string
	Trace string
}

type HostDB struct {
	apiRW string
	apiRO string
	readOnly bool
	user string
	session string
	LastStatus httpStatus
}

type yamlConf struct {
	HostdbRW string `yaml:"hostdb_rw"`
	HostdbRO string `yaml:"hostdb_ro"`
}

func New(params *Config) (*HostDB, error) {
	hostdb := new(HostDB)
	config := yamlConf{}
	if err := LoadConf("/etc/hostdb/client_conf.yaml",&config); err != nil {
	//if err := LoadConf("./client_conf.yaml",&config); err != nil {
		return hostdb, err
	}
	hostdb.apiRW = fmt.Sprintf("%s://%s/%s",proto,setParam(params.Server,config.HostdbRW),version)
	hostdb.apiRO = fmt.Sprintf("%s://%s/%s",proto,setParam(params.Server,setParam(config.HostdbRO,config.HostdbRW)),version)
	hostdb.readOnly = true
	if err := authenticate(hostdb,params); err != nil {
		return hostdb, err
	}
	return hostdb, nil
}

func setParam(mainKey string, defaultKey string) string {
	if mainKey != "" {
		return mainKey
	}
	return defaultKey
}

func authenticate(hostdb *HostDB, params *Config) error {
	if params.Session != "" {
		uri := fmt.Sprintf("%s/auth/session/%s",hostdb.apiRW,params.Session)
		resp, err := http.Get(uri)
		if err != nil {
			return err
		}
		if hostdb.user, err = hostdb.getRespBody(resp); err != nil {
			return err
		}
		hostdb.session = params.Session
		hostdb.readOnly = false
	} else if params.User != "" && params.Password != "" {
		uri := fmt.Sprintf("%s/auth/session",hostdb.apiRW)
		resp, err := http.PostForm(uri,url.Values{"username": {params.User},"password": {params.Password}})
		if err != nil {
			return err
		}
		if hostdb.session, err = hostdb.getRespBody(resp); err != nil {
			return err
		}
		hostdb.user = params.User
		hostdb.readOnly = false
	}
	return nil
}

/*
 args[0] - string - id
 args[1] - int - revision
 args[2] - bool - raw
*/
func (hostdb *HostDB) Get(args ...interface{}) (string, error) {
	uri := fmt.Sprintf("%s/%s",hostdb.apiRO,args[0].(string))
	sep := "?"
	if len(args) > 1 && args[1].(string) != "" {
		uri = fmt.Sprintf("%s%srevision=%d",uri,sep,args[1].(string))
		sep = "&"
	}
	if len(args) > 2 && args[2].(bool) == true {
		uri = fmt.Sprintf("%s%sraw=%t",uri,sep,args[2].(bool))
	}
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) MultiGet(args ...string) (string, error) {
	if len(args) < 2 { return "",InvalidParams }
	uri := fmt.Sprintf("%s/%s?foreach=%s",hostdb.apiRO,args[0],args[1])
	if len(args) > 2 {
		uri = fmt.Sprintf("%s&revision=%s",uri,args[2])
	}
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) Parents(host, namespace string) (string, error) {
	uri := fmt.Sprintf("%s/hosts/%s?meta=parent&from=%s",hostdb.apiRO,host,namespace)
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) Derived(host, namespace string) (string, error) {
	uri := fmt.Sprintf("%s/hosts/%s?meta=derived&from=%s",hostdb.apiRO,host,namespace)
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) Revisions(args ...interface{}) (string, error) {
	uri := fmt.Sprintf("%s/%s?meta=revisions",hostdb.apiRO,args[0].(string))
	if len(args) > 1 {
		uri = fmt.Sprintf("%s&limit=%d",uri,args[1].(int))
	}
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) Set(id, value, log string) (string, error) {
	uri := fmt.Sprintf("%s/%s",hostdb.apiRW,id)
	if strings.Contains(id,"/members") {
		log = value
		value = ""
	}
	form := url.Values{"value": {value}, "log": {log}, "session": {hostdb.session}}
	req, err := http.NewRequest("PUT",uri,bytes.NewBufferString(form.Encode()))
	if err != nil {
		return "",err
	}
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) Rename(id, newname, log string) (string, error) {
	uri := fmt.Sprintf("%s/%s",hostdb.apiRW,id)
	resp, err := http.PostForm(uri,url.Values{"newname": {newname}, "log": {log}, "session": {hostdb.session}})
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) Delete(id, log string) (string, error) {
	//form := url.Values{"log": {log}, "session": {hostdb.session}}
	//uri := fmt.Sprintf("%s/%s?%s",hostdb.apiRW,id,form.Encode())
	//uri := fmt.Sprintf("%s/%s",hostdb.apiRW,id)
	//fmt.Println(uri)
	uri := fmt.Sprintf("%s/%s?log=%s&session=%s",hostdb.apiRW,id,spaceConversion(log),hostdb.session)
	req, err := http.NewRequest("DELETE",uri,nil)
	//req, err := http.NewRequest("DELETE",uri,bytes.NewBufferString(form.Encode()))
	if err != nil {
		return "",err
	}
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "",err
	}
	return hostdb.getRespBody(resp)
}

func (hostdb *HostDB) getRespBody (resp *http.Response) (string, error) {
	defer resp.Body.Close()
	if resp.StatusCode != 200 && resp.StatusCode != 201 {
		hostdb.LastStatus.Code = resp.StatusCode
		hostdb.LastStatus.Message = resp.Status
		//if _, ok := resp.Header["Calltrace"]; ok {
		hostdb.LastStatus.Trace = resp.Header["Calltrace"][0]
		//}
		return "",RequestFailed
	}
	content,err := ioutil.ReadAll(resp.Body)
	return string(content),err
}

func spaceConversion(str string) string {
	return strings.Replace(str," ","_",-1)
}
