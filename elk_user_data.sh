#!/bin/bash
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-17-jre-headless
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
sudo apt update -y
sudo apt install -y elasticsearch
cat <<EOF | sudo tee -a /etc/elasticsearch/elasticsearch.yml > /dev/null
network.host: 0.0.0.0
cluster.name: my-cluster
node.name: node-1
discovery.type: single-node
EOF
sudo systemctl start elasticsearch --now
sudo systemctl enable elasticsearch --now
# sudo systemctl status elasticsearch
# curl -X GET "http://localhost:9200"
sudo apt install logstash -y
sudo tee /etc/logstash/conf.d/logstash.conf > /dev/null <<EOL
input {
    beats {
        port => 5044
    }
}
filter {
    grok {
        match => { "message" => "%{TIMESTAMP_ISO8601:log_timestamp} %{LOGLEVEL:loglevel} %{GREEDYDATA:log_message}" }
    }
}
output {
    elasticsearch {
        hosts => ["http://localhost:9200"]
        index => "logs-%{+YYYY.MM.dd}"
    }
    stdout { codec => rubydebug }
}
EOL
sudo systemctl start logstash --now
sudo systemctl enable logstash --now
# sudo systemctl status logstash
sudo apt install -y kibana
cat <<EOF | sudo tee -a /etc/kibana/kibana.yml > /dev/null
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
EOF
# sudo sed -i 's/^#server.host: "localhost"/server.host: "0.0.0.0"/' /etc/kibana/kibana.yml
# sudo sed -i 's/^#elasticsearch.hosts: \["http:\/\/localhost:9200"\]/elasticsearch.hosts: \["http:\/\/localhost:9200"\]/' /etc/kibana/kibana.yml
# sudo cat /etc/kibana/kibana.yml | grep server.host
# sudo cat /etc/kibana/kibana.yml | grep elasticsearch.hosts
sudo systemctl start kibana --now
sudo systemctl enable kibana --now
# sudo systemctl status kibana
# http://localhost:5601

