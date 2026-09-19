#!/bin/bash
# usage: ./docker.sh start|stop <challenge_id>
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
api POST "/challenges/containers/$1" "{\"id\":$2}"; echo
