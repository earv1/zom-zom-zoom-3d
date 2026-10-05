#!/usr/bin/env bash
# Rebuilds the boss voice SFX from the CC BY-SA source recordings (see assets/audio/boss/CREDITS.md).
# One clean call + one long scream per stage: hadeda (clean), zadeda (a zombie growl
# vocoded by the hadeda's call), cydeda (robot).
set -euo pipefail
TOOLS="$(cd "$(dirname "$0")" && pwd)"
cd "$TOOLS/../assets/audio/boss"
SRC_CALL=source/hadeda_call_amada44.flac
SRC_LONG=source/hadeda_pretoria_jmk.mp3
SRC_MOAN=source/zombie_moan_gregoryweir.ogg          # public domain, ~1 s of groan
SRC_GUT=source/zombie_guttural_wowsuchthings.ogg     # CC BY-SA 4.0, growl bursts

# Shared clean-up: mono, trim rumble/hiss (loudnorm runs last; it resamples to 192k).
CLEAN="aformat=channel_layouts=mono,highpass=f=250,lowpass=f=9000,aresample=44100"
# Zombie bird: the hadeda pitched down a touch (it then drives the vocoder).
UNDEAD="asetrate=44100*0.88,aresample=44100"
# Robot: phase-zeroed FFT (monotone vocoder buzz), ring-mod, bitcrush, short metallic comb.
ROBOT="afftfilt=real='hypot(re,im)':imag='0':win_size=512:overlap=0.75,aeval='val(0)*(0.55+0.45*sin(2*PI*70*t))',acrusher=bits=6:samples=3:mix=0.6,aecho=0.8:0.6:7|13:0.45|0.3,highpass=f=180"

make() { # name input trim-args extra-filter
	ffmpeg -hide_banner -loglevel error -y $3 -i "$2" \
		-af "$CLEAN${4:+,$4},afade=t=in:d=0.02,areverse,afade=t=in:d=0.15,areverse,loudnorm=I=-14:TP=-1.5" \
		-ar 44100 -ac 1 -c:a pcm_s16le "$1.wav"
}
SCREAM="-ss 14.25 -t 4.25"
make hadeda_call  "$SRC_CALL" ""
make hadeda_scream "$SRC_LONG" "$SCREAM"
# zadeda: cross-synthesis (tools/cross_synth.py). The zombie growl is the voice,
# the hadeda's call shapes it frame by frame: one growling bird, not two sounds.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
GROWLS="[0:a]aformat=channel_layouts=mono,aresample=44100,asplit=2[g1][g2];[g1]atrim=9.4:12.1,asetpts=PTS-STARTPTS[a1];[g2]atrim=14.4:17.1,asetpts=PTS-STARTPTS[a2];[a1][a2]acrossfade=d=0.4[g];[1:a]aformat=channel_layouts=mono,aresample=44100,atrim=0:1.2,asetrate=44100*0.9,aresample=44100,apad=pad_dur=0.6[m];[g][m]amix=inputs=2:duration=longest:weights=1 0.8"
ffmpeg -hide_banner -loglevel error -y -i "$SRC_GUT" -i "$SRC_MOAN" -filter_complex "$GROWLS" -ar 44100 -ac 1 "$TMP/zombie.wav"
undead() { # name bird-input bird-trim keep(plain hadeda mixed back in)
	ffmpeg -hide_banner -loglevel error -y $3 -i "$2" -af "$CLEAN,$UNDEAD" -ar 44100 -ac 1 "$TMP/bird.wav"
	python3 "$TOOLS/cross_synth.py" "$TMP/bird.wav" "$TMP/zombie.wav" "$TMP/voiced.wav" --keep "$4" --lifter 36
	ffmpeg -hide_banner -loglevel error -y -i "$TMP/voiced.wav" \
		-af "highpass=f=90,afade=t=in:d=0.02,areverse,afade=t=in:d=0.2,areverse,loudnorm=I=-14:TP=-1.5" \
		-ar 44100 -ac 1 -c:a pcm_s16le "$1.wav"
}
undead zadeda_call "$SRC_CALL" "" 0.25           # a touch more bird in the short call
undead zadeda_scream "$SRC_LONG" "$SCREAM" 0.2
make cydeda_call  "$SRC_CALL" "" "$ROBOT"
make cydeda_scream "$SRC_LONG" "$SCREAM" "$ROBOT"
ls -la *.wav
