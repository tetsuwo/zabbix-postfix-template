#!/usr/bin/env sh
#
# Usage:
#   ./maillog-summary.sh
#

MAILLOG=/var/log/maillog
OFFSET_FILE=/tmp/zabbix_postfix-offset.dat
TEMP_FILE=$(mktemp)
PFLOGSUMM=/usr/sbin/pflogsumm
ZABBIX_CONF=/etc/zabbix/zabbix_agentd.conf
ZABBIX_SEND=/usr/bin/zabbix_sender
DEBUG=1
ZABBIX_FLAG=1

function zabbix_send {
  [ ${DEBUG} -ne 0 ] && echo "Send key \"$1\" with value \"$2\"" >&2
  [ ${ZABBIX_FLAG} -ne 0 ] && $ZABBIX_SEND -c $ZABBIX_CONF -k "$1" -o "$2" 2>&1 >/dev/null
}
function send_postfix {
  key=$1
  value=`grep -m 1 "$2" $TEMP_FILE | awk '{print $1}'`
  zabbix_send $key $value
}

HEAD_POS=""
if [ -e "${OFFSET_FILE}" ]; then
  HEAD_POS=`cat ${OFFSET_FILE}`
fi
expr "${HEAD_POS}" + 1 > /dev/null 2>&1
if [ ! $? -lt 2 ]; then
  HEAD_POS=1
fi

TAIL_POS=`less ${MAILLOG} | wc -l`
expr "${TAIL_POS}" + 1 > /dev/null 2>&1
if [ ! $? -lt 2 ]; then
  echo "Cannot count maillog lines"
  exit 1
fi
if [ $HEAD_POS -eq $TAIL_POS ]; then
  echo "Same value offset line number and maillog lines"
  exit 1
fi

echo "HEAD: ${HEAD_POS} / TAIL: ${TAIL_POS}"

cat $MAILLOG | sed -n "${HEAD_POS},${TAIL_POS}p" \
    | $PFLOGSUMM -h 0 -u 0 --no_bounce_detail --no_deferral_detail \
      --no_reject_detail --no_no_msg_size --no_smtpd_warnings > $TEMP_FILE

send_postfix 'postfix.status.bounced'           'bounced'
#send_postfix 'postfix.status.bytes_delivered'   'bytes delivered'
#send_postfix 'postfix.status.bytes_received'    'bytes received'
send_postfix 'postfix.status.deferred'          'deferred'
send_postfix 'postfix.status.discarded'         'discarded'
send_postfix 'postfix.status.delivered'         'delivered'
send_postfix 'postfix.status.forwarded'         'forwarded'
send_postfix 'postfix.status.held'              'held'
send_postfix 'postfix.status.received'          'received'
send_postfix 'postfix.status.recipients'        'recipients'
send_postfix 'postfix.status.recipient_hosts'   'recipient hosts'
send_postfix 'postfix.status.reject_warnings'   'reject warnings'
send_postfix 'postfix.status.rejected'          'rejected'
send_postfix 'postfix.status.senders'           'senders'
send_postfix 'postfix.status.sending_hosts'     'sending hosts'

echo $TAIL_POS > $OFFSET_FILE
rm $TEMP_FILE

exit 0
