D=/home/acidburn/ctf/events/NoQRTR2026
CT=$(tr -d '\r\n' < "$D/.ctf_token")
CTFID=3563
api() { # api METHOD PATH [JSONBODY]
  local m="$1" p="$2" b="${3:-}"
  if [ -n "$b" ]; then
    curl -s -m 30 -X "$m" -H "Authorization: Bearer $CT" -H 'Accept: application/json' \
      -H 'Content-Type: application/json' -d "$b" "https://ctf.hackthebox.com/api$p"
  else
    curl -s -m 30 -X "$m" -H "Authorization: Bearer $CT" -H 'Accept: application/json' \
      "https://ctf.hackthebox.com/api$p"
  fi
}
