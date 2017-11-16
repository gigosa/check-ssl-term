#!/bin/bash
readonly CHECK_SSL_FILE=/path/to/check/list
readonly ERROR_LOG=/path/to/error/log
#readonly now_date=$(date "+%Y/%m")
readonly next_month=$(date -d"1 months" "+%Y/%m")
err_flag=0
echo $now_date
function show_ssl_enddate(){
    date -d"$(openssl s_client -connect $1 < /dev/null 2> /dev/null | openssl x509 -enddate -noout | sed 's/notAfter=//g')" "+%Y/%m/%d" 2>> $ERROR_LOG
    return $?
}

function send_mail(){
    local From="example@example.com"
    local To="your-mail@ddress.com"
    local Subject="SSL "${next_month}
    cat << EOM | nkf -j | sendmail -t
From: $From
To: $To
Subject: $Subject
MIME-Version: 1.0
Content-Type: text/plain; charset="ISO-2022-JP"

${next_month}に以下の証明書が期限が切れます。

$(for ssl_value in "${ssl_data[@]}"
do
   echo ${ssl_value}
done)

以上${#ssl_data[@]}件です。
EOM
}

function send_err_mail(){
    local From="example@example.com"
    local To="your-mail@ddress.com"
    local Subject="error"
    cat <<EOM | nkf -j | sendmail -t
From: $From
To: $To
Subject: $Subject
MIME-Version: 1.0
Content-Type: text/plain; charset="ISO-2022-JP"

$(cat ${ERROR_LOG})
EOM
}
    
echo -n > $ERROR_LOG
while read ssl_line
do
    #iniのコメントアウトを除外する処理
    echo $ssl_line | grep -v '^#.*' > /dev/null
    if [ $? -eq 1 ]; then
        continue
    fi
    ssl_end_date=$(show_ssl_enddate ${ssl_line})
    if [ $? -eq 1 ];then
        echo Error on ${ssl_line} >> $ERROR_LOG
        err_flag=1
        continue
    fi
    ssl_end_month=$(date -d"${ssl_end_date}" "+%Y/%m")
    if [ $next_month == $ssl_end_month ]; then
        ssl_data+=($(echo ${ssl_line} | cut -d: -f1):${ssl_end_date})
    fi
done < $CHECK_SSL_FILE
if [ $err_flag -eq 0 ]; then
    send_mail
else
    send_err_mail
fi
exit 0
