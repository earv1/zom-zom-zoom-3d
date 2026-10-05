# Boss voice credits

The hadeda / zadeda / cydeda voices are processed from these recordings of the
Hadada ibis (*Bostrychia hagedash*), via Wikimedia Commons. The processed clips
(`*_call.wav`, `*_scream.wav`, made by `tools/make_hadeda_sfx.sh`) are shared
under the same licences.

- **"Bostrychia hagedash call"** by Amada44, licensed CC BY-SA 3.0
  https://commons.wikimedia.org/wiki/File:Bostrychia_hagedash_call.flac
  https://creativecommons.org/licenses/by-sa/3.0/
  -> `source/hadeda_call_amada44.flac`; used for `*_call.wav`

- **"Bostrychia hagedash hagadash, roepe 20s, 2022-09-25 06h43, Pretoria, a"** by JMK,
  licensed CC BY-SA 4.0
  https://commons.wikimedia.org/wiki/File:Bostrychia_hagedash_hagadash,_roepe_20s,_2022-09-25_06h43,_Pretoria,_a.mp3
  https://creativecommons.org/licenses/by-sa/4.0/
  -> `source/hadeda_pretoria_jmk.mp3`, 14.25 s to 18.5 s; used for `*_scream.wav`

The zadeda (zombie) voice layers the hadeda over these zombie recordings, also
from Wikimedia Commons:

- **"Zombie moan"** by gregoryweir, public domain
  https://commons.wikimedia.org/wiki/File:Zombie_moan.ogg
  -> `source/zombie_moan_gregoryweir.ogg`; under `zadeda_call.wav`

- **"Zombie-Gutteral-Sounds"** by Wowsuchthings, licensed CC BY-SA 4.0
  https://commons.wikimedia.org/wiki/File:Zombie-Gutteral-Sounds.ogg
  https://creativecommons.org/licenses/by-sa/4.0/
  -> `source/zombie_guttural_wowsuchthings.ogg`, 9.4-12.1 s and 14.4-17.1 s; under `zadeda_scream.wav`

Changes: trimmed, filtered, normalised, mixed; zadeda is pitched down slightly
and layered over the zombie recordings; cydeda is FFT-robotised, ring-modulated,
bit-crushed and comb-echoed.
