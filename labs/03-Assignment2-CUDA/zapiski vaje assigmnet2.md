Za kaj je najbolje razbijati grid po kvadratih za GPU (ne po stolpcih/vrsticah)?

$$
N = 256 \cdot 256 = 65536
$$

$$
T_b = 1024 = 2^{10}
$$

$$
K = 26 \cdot 26 = 676
$$

Velikost kernela: $26 \times 26$.
Število blokov 64, torej 4 vrstice dolžine 256 v vsakem bloku.

Število koliko celic moramo prenesti v multiprocesor GPU-ja
## PASOVNA DELITEV
$$
N_p = 64 * (1024 + 2 * (256 + 13 * 2)* 13) = 534784 ~ 534k
$$
= število vseh blokov * (št. niti na blok + 2 [gor dol] * (dolžina vrstice + levi in desni z extro širino kernela) * kernel size)

## BLOČNA DELITEV
$$
velikost bloka  32*32 = 1024
N_b = 64 * (1024 + 4 * (32 + 13)*13) = 215296 ~ 215k
$$
= število vseh blokov * (št. niti + 4 [smeri gor dol levo desno] * (velikost bloka + sosedi izven kvadtata) * kernel size)

### Makefile 
- prirpavljena za prevajanja GPU kode
v src/main.c 
- definirana simulacija (št obriumov)
### Lenia.cu 
- TODO implementacija CUDA kode
- dodatna #GENRATE GIF konstanta, ki vklopi/izklopi generiranje gif animacije
### obrium.c 
- definira obriume, več različnih možnih orientacij
- run leania.sh - skripta za zagon simulacije na Arnesu
## OSNOVA:
- Lotričeva koda za stancil
- GPU kodo na gpu vozlišču, CPU vozlišče na CPU rezervaciji (1h+ za 4096x4096, zato na CPU vozlišču)
- hroč: po določenih iteracija Orbium izgine 

## DODATNO
### Optimizacija CPU kode z OpenMP-om: 
- opptimizacija cpu kode z OpenMP-om: združi konvolucijo in lena simulacijo (v enem loopu)
- izboljšaj računaje gausa (pow operacija je draga)
- ne izvajanje gausa za ničelne celice, izračunaj vredost in shranjuj v cahcke
- iz double -> float
- to je potem baseline za izračun speedupa, bolj pravičen CPE vs GPE primerjava
### Shared memory:
- pričakuj do 5kratno pohitritev, če že na začetku instanciramo blok v delejeni pomnilnik
### Konvolucija:
- dvojno zrcaljenje -> za boljši performance zrcali krenel gor dol in levo desno, da je inteksiranje računanja konvolucij enako kot GPU računa, trenutno ni tako (x0,y0=levo spodaj, za GPUju pa desno zgoraj)

shared koda v heat4 ne dela pravilno -> napačno indeksiranje (idejno je v redu, rezultat napačen, bodo popravl)