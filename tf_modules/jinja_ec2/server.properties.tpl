broker.id=${id}
# change this to the hostname of each broker
advertised.listeners=PLAINTEXT://kafka${id}:9092
# The ability to delete topics
delete.topic.enable=true
# Where logs are stored
log.dirs=/data/kafka
# default number of partitions
num.partitions=8
# default replica count based on the number of brokers
default.replication.factor=3
# to protect yourself against broker failure
min.insync.replicas=2
# logs will be deleted after how many hours
log.retention.hours=168
# size of the log files 
log.segment.bytes=1073741824
# check to see if any data needs to be deleted
log.retention.check.interval.ms=300000
# location of all zookeeper instances and kafka directory
zookeeper.connect=zookeeper1:2181,zookeeper2:2181/kafka
# timeout for connecting with zookeeeper
zookeeper.connection.timeout.ms=6000
# automatically create topics
auto.create.topics.enable=true