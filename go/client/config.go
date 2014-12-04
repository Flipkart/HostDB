package hostdb

import (
	"gopkg.in/yaml.v2"
	"io/ioutil"
	"strconv"
//	"fmt"
)

type YamlConfig struct {
	config map[interface{}]interface{}
}

func LoadConfig(file string) (*YamlConfig,error) {
	yamlConfig := &YamlConfig{}
	data, err := ioutil.ReadFile(file)
	if err != nil {
		return yamlConfig,err
	}
	err = yaml.Unmarshal(data,&yamlConfig.config)
	return yamlConfig,err
}

func (c *YamlConfig) Get(args ...string) interface{} {
	//var empty interface{}
	var value interface{} = c.config
	for i := range args {
		switch value.(type) {
		case map[interface{}]interface{}:
			for k,v := range value.(map[interface{}]interface{}) {
				switch k.(type) {
				case string:
					if args[i] == k.(string) {
						value = v
						continue
					}
				case int:
					if args[i] == strconv.FormatInt(int64(k.(int)),10) {
						value = v
						continue
					}
				case float64:
					//fmt.Println(args[i],strconv.FormatFloat(k.(float64),'g',-1,64))
					if args[i] == strconv.FormatFloat(k.(float64),'g',-1,64) {
						value = v
						continue
					}
				default:
					return nil
				}
			}
		default:
			return nil
		}
	}
	return value
}
