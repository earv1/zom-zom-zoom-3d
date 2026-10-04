#!/usr/bin/env bash
# Rebuilds the boss voice SFX from the CC BY-SA source recordings (see assets/audio/boss/CREDITS.md).
# One clean call + one long scream per stage: hadeda (clean), zadeda (raspy zombie), cydeda (robot).
set -euo pipefail
cd "$(dirname "$0")/../assets/audio/boss"
SRC_CALL=source/hadeda_call_amada44.flac
SRC_LONG=source/hadeda_pretoria_jmk.mp3

# Shared clean-up: mono, trim rumble/hiss (loudnorm runs last; it resamples to 192k).
CLEAN="aformat=channel_layouts=mono,highpass=f=250,lowpass=f=9000,aresample=44100"
# Zombie: pitched down, gravelly flutter, crushed and soft-clipped for a wet rasp.
RASPY="asetrate=44100*0.82,aresample=44100,vibrato=f=28:d=0.35,volume=6dB,asoftclip=type=atan,acrusher=bits=7:mix=0.35:mode=log,lowpass=f=5500,tremolo=f=11:d=0.25"
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
make zadeda_call  "$SRC_CALL" "" "$RASPY"
make zadeda_scream "$SRC_LONG" "$SCREAM" "$RASPY"
make cydeda_call  "$SRC_CALL" "" "$ROBOT"
make cydeda_scream "$SRC_LONG" "$SCREAM" "$ROBOT"
ls -la *.wav
