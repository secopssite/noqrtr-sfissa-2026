#!/bin/bash
# usage: ./spawn.sh spawn|reset|extend|destroy <challenge_id>
. /home/acidburn/ctf/events/NoQRTR2026/_lib.sh
api POST "/challenges/machines/$1/$2"; echo
