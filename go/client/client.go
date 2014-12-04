package hostdb

import (
	"fmt"
	"net/http"
	"errors"
	"net/url"
	"strings"
)

const (
	proto = "https"
	version = "v1"
)

var UnknownLength = errors.New("length of http response is unknown")
var InvalidParams = errors.New("parameters are invalid/missing")

type Config struct {
	User string
	Password string
	Session string
	Server string
}

/*
type httpStatus struct {
	Code int
	Message string
	Trace string
}
*/

type HostDB struct {
	apiRW string
	apiRO string
	readOnly bool
	user string
	session string
	//LastStatus httpStatus
}

func New(params *Config) (*HostDB, error) {
	hostdb := new(HostDB)
	config, err := LoadConfig("/etc/hostdb/client_conf.yaml")
	if err != nil {
		return hostdb, err
	}
	var value interface{}
	var hostdb_rw,hostdb_ro string
	if value = config.Get("hostdb_rw"); value != nil {
		hostdb_rw = value.(string)
	}
	if value = config.Get("hostdb_ro"); value != nil {
		hostdb_ro = value.(string)
	}
	hostdb.apiRW = fmt.Sprintf("%s://%s/%s",proto,setParam(params.Server,hostdb_rw),version)
	hostdb.apiRO = fmt.Sprintf("%s://%s/%s",proto,setParam(params.Server,setParam(hostdb_ro,hostdb_rw)),version)
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
		if hostdb.user, err = getRespBody(resp); err != nil {
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
		if hostdb.session, err = getRespBody(resp); err != nil {
			return err
		}
		hostdb.user = params.User
		hostdb.readOnly = false
	}// else {
	//	return InvalidParams
	//}
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
	return getRespBody(resp)
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
	return getRespBody(resp)
}

func (hostdb *HostDB) Parents(host, namespace string) (string, error) {
	uri := fmt.Sprintf("%s/hosts/%s?meta=parent&from=%s",hostdb.apiRO,host,namespace)
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return getRespBody(resp)
}

func (hostdb *HostDB) Derived(host, namespace string) (string, error) {
	uri := fmt.Sprintf("%s/hosts/%s?meta=derived&from=%s",hostdb.apiRO,host,namespace)
	resp, err := http.Get(uri)
	if err != nil {
		return "",err
	}
	return getRespBody(resp)
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
	return getRespBody(resp)
}

func (hostdb *HostDB) Set(id, value, log string) (string, error) {
	uri := fmt.Sprintf("%s/%s",hostdb.apiRW,id)
	if strings.Contains(id,"/members") {
		log = value
		value = ""
	}
	req, err := http.NewRequest("PUT",uri,nil)
	if err != nil {
		return "",err
	}
	req.Form = url.Values{"value": {value}, "log": {log}, "session": {hostdb.session}}
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "",err
	}
	return getRespBody(resp)
}

func (hostdb *HostDB) Rename(id, newname, log string) (string, error) {
	uri := fmt.Sprintf("%s/%s",hostdb.apiRW,id)
	resp, err := http.PostForm(uri,url.Values{"newname": {newname}, "log": {log}, "session": {hostdb.session}})
	if err != nil {
		return "",err
	}
	return getRespBody(resp)
}

func (hostdb *HostDB) Delete(id, log string) (string, error) {
	uri := fmt.Sprintf("%s/%s?log=%s&session=%s",hostdb.apiRW,id,log,hostdb.session)
	req, err := http.NewRequest("DELETE",uri,nil)
	if err != nil {
		return "",err
	}
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return "",err
	}
	return getRespBody(resp)
}

func getRespBody (resp *http.Response) (string, error) {
	if resp.ContentLength == -1 {
		return "",UnknownLength
	}
	respBody := make([]byte,resp.ContentLength)
	if _, err := resp.Body.Read(respBody); err != nil {
		return "",err
	}
	resp.Body.Close()
	return string(respBody),nil
}
