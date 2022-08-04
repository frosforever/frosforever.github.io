---
layout: post
title: "Overwrite custom log4j2 in spark 3.3.x with Databricks runtime > 11"
description: "How to provide custom log settings using log4j2 with Databricks runtime"
---

Spark 3.3 has upgraded its logging from log4j to log4j2. Guidance on custom log settings prior to Spark 3.3 (e.g. [here](https://kb.databricks.com/en_US/clusters/overwrite-log4j-logs) and [here](https://mostlymaths.net/2021/01/databricks-log4j-configuration.html/) etc) is no longer correct. This is a best effort recommendation based on what seems to be working for me in DBR 11.1.

Similar to the methods used with log4j 1, we need to provide an init script to the cluster that will create a `log4j2.properties` file on the driver / executor.

{% highlight shell %}
#! /bin/bash

set -euxo pipefail

echo "Running on the driver? ${DB_IS_DRIVER}"
echo "Driver ip: ${DB_DRIVER_IP}"

cat >>/databricks/spark/dbconf/log4j/driver/log4j2.properties <<EOL

appender.customFile.type = RollingFile
appender.customFile.name = customFile
appender.customFile.layout.type = PatternLayout
appender.customFile.layout.pattern = %d{yy/MM/dd HH:mm:ss} %p %c{1}: %m%n%ex
appender.customFile.filePattern = logs/log4j.custom.%d{yyyy-MM-dd-HH}.log.gz
appender.customFile.policies.type = Policies
appender.customFile.policies.time.type = TimeBasedTriggeringPolicy
appender.customFile.policies.time.interval = 1
appender.customFile.fileName = logs/stdout.custom-active.log

logger.custom=DEBUG, customFile
logger.custom.name = com.custom
logger.custom.additivity = true

EOL
{% endhighlight %}

### What this script does
* Creates a `log4j2.properties` file under `/databricks/spark/dbconf/log4j/driver/log4j2.properties`. Note this is no longer `log4j.properties`! Executor logging can be set via `/databricks/spark/dbconf/log4j/executor/log4j2.properties`.
* In the [properties files](https://logging.apache.org/log4j/2.x/manual/configuration.html#SystemProperties) we define
  * A custom `RollingFile` appender called `customFile` that will roll files every hour, the most specific time unit in the filePattern's date pattern, into a gzipped path.
  * A custom logger for everything under `com.custom` to log to other loggers (so we keep stdout etc) and also log to our customFile appender at the `DEBUG` level

There is another notable difference between the prior log4j1 guidance. Databricks used a custom redacting file appender from `com.databricks.logging.RedactionRollingFileAppender` that no longer seems available. As far as I can tell, there is no updated log4j2 supported redacting appender from Databricks.

Be sure to set this file in the [cluster init scripts](https://docs.databricks.com/dev-tools/api/latest/clusters.html#clusterclusterinitscriptinfo):

{% highlight json %}
...
  "init_scripts": [
    {
      "s3": {
        "destination": "s3://foo/bar/log4j2_config.sh"
        "region": "us-east-1"
      }
    }
  ]
...
{% endhighlight %}

