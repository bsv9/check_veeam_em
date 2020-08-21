# check_veeam_em

This plugin checks Veeam job status via Veeam Backup Enterprise Manager REST API

## Requirements
* Ruby >= 2.0

## Options

    -a, --address ADDRESS            Veeam EM base API host
    -p, --port PORT                  API port
    -k, --insecure                   No ssl verification
    -n, --name NAME                  Job name
    -U, --username USERNAME          Username
    -P, --password PASSWORD          Password
    -w, --warning WARNING            Warning days threshold
    -c, --critical CRITICAL          Critical days threshold
    -v, --version                    Print version information
    -h, --help                       Show this help message


# Example of use


    $ ./check_veeam_em.rb -a <veem_em_ip_or_hostname> -U xxx -P xxx  -k -n <backup-job-xxx>
    OK - Job JOB1 completed successfully 2020-08-18 02:21:14 UTC
    $

## Check command definition:


# License

[MIT](https://opensource.org/licenses/MIT)

# Author
Sergey V. Beduev