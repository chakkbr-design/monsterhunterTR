# Inventário Pixel Lab para a Batalha Viva

Gerado listando a conta (grátis; 0 gerações gastas). Galeria: 1545 imagens; objetos: 940. Descrições da API vêm truncadas.

## 1. Usadas no jogo (copiadas para assets/pixellab/)

| arquivo | origem | descrição | tam | uso |
|---|---|---|---|---|
| fx/fire_burst.png | obj 2bbd9f85 | explosão laranja de fogo | 64x64 | estouro fire (reações blaze/melt, duplas fogo) |
| fx/arcane_burst.png | obj dffc9417 | explosão arcana roxa | 64x64 | psychic/dragon |
| fx/poison_burst.png | obj c895a207 | nuvem tóxica verde | 64x64 | poison/bug (venom) |
| fx/dust_ring.png | obj 5d09aae3 | anel de poeira marrom | 64x64 | ground (sandstorm, mud); decalque 'dust' |
| fx/stone_ring.png | obj 633e7433 | anel de pedras rachadas | 64x64 | rock; decalque 'crater' |
| fx/wind_ring.png | obj e36612c9 | anel de vento/gelo ciano | 64x64 | ice/flying (freeze) |
| fx/leaf_ring.png | obj e527413d | anel verde de folhas | 64x64 | grass (pollen_blast) |
| fx/water_swirl.png | obj 1d868889 | redemoinho de água | 64x64 | water; decalque 'puddle' |
| fx/curse_circle.png | obj 0a0c9f49 | círculo de maldição roxo | 64x64 | ghost/dark (nightmare) |
| fx/infernal_circle.png | obj 4e8c80e3 | círculo infernal vermelho | 64x64 | decalque 'scorch' (escurecido) |
| fx/ice_patch.png | obj 0466a5dd | placa de gelo | 84x84 | decalque 'ice' |
| fx/slime_puddle.png | obj 73feb4f6 | poça de gosma verde | 64x64 | reserva (poça/veneno) |
| fx/electric_orb.png | obj 14dc46b6 | orbe elétrico azul | 32x32 | reserva |
| fx/impact_yellow.png | obj 3fc4a2a5 | faísca de impacto amarela | 32x32 | normal/steel, CLASH |
| fx/impact_red.png | obj 7f278863 | estouro vermelho/laranja | 32x32 | fighting (ground_combo) |
| fx/spark_purple.png | obj e831b2cc | brilho mágico roxo | 16x16 | fairy |
| fx/spark_blue.png | obj 339de009 | brilho azul | 32x32 | faísca do início dos golpes de dupla |
| fx/snowflake.png | obj d6e155f2 | floco de neve | 32x32 | freeze |
| fx/lightning.png | obj 95ddb80b | raio amarelo | 16x16 | reserva |
| fx/leaf.png | obj 656e3f46 | folha verde | 16x16 | reserva |
| fx/shockwave.png | obj a2e985ef | anel de onda de choque | 20x20 | CLASH |
| fx/bubble.png | obj 6df5bc8d | bolha/escudo ciano | 20x20 | reserva (escudos) |
| fx/fire_loop.png | galeria e313ce1e quadros 24-31 (grade 8x8 de 16px) | tira 1x8: fogo pulsando | 16x16 x8 | reserva (animado) |
| fx/flame_loop.png | galeria e475b08d quadros 0-7 | tira 1x8: chama | 16x16 x8 | reserva (animado) |
| fx/electric_loop.png | galeria 0c5342e2 quadros 8-15 (24px) | tira 1x8: orbe elétrico | 24x24 x8 | estouro electric (animado) |
| fx/spark_loop.png | galeria f32715e7 quadros 24-31 | tira 1x8: faísca amarela | 16x16 x8 | reserva (animado) |
| objects/crate.png | obj a34c8567 | caixa de madeira velha | 32x32 | caixa que quebra |
| objects/rock.png | obj 31b7f9dc | pedra musgosa | 32x32 | pedra que quebra |
| objects/berry.png | obj a216beaa | folha enrolada com coração | 32x32 | frutinha |
| objects/debris_rock.png | obj 9a7cf882 | pedaços de pedra | 32x32 | estilhaços de pedra |
| objects/debris_crate.png | obj 4de34f2e | pilha de lascas marrons | 32x32 | estilhaços de caixa |
| icons/cmd_ofensivo.png | galeria feaf9410 quadro 38 | espadas cruzadas | 32x32 | comando OFENSIVO |
| icons/cmd_defensivo.png | galeria feaf9410 quadro 34 | escudo | 32x32 | comando DEFENSIVO |
| icons/cmd_suporte.png | galeria feaf9410 quadro 26 | coração com cruz | 32x32 | comando SUPORTE |
| icons/cmd_livre.png | galeria feaf9410 quadro 42 | asas | 32x32 | comando LIVRE |
| icons/mark_wet.png | galeria feaf9410 quadro 37 | gota | 32x32 | marca Molhado |
| icons/mark_burning.png | galeria 1c6d440f quadro 4 | chama | 32x32 | marca Em brasa |
| icons/mark_pollen.png | galeria feaf9410 quadro 8 | flor com pólen | 32x32 | marca Pólen |
| icons/mark_dust.png | obj a021bedc | pedras | 24x24 | marca Pó |
| icons/mark_down.png | galeria 1c6d440f quadro 31 | punho | 32x32 | marca Derrubado |
| icons/mark_psy.png | galeria 1c6d440f quadro 7 | espiral roxa | 32x32 | marca Confuso |
| icons/mark_slow.png | galeria feaf9410 quadro 44 | floco de neve | 32x32 | marca Lento |
| icons/sync.png | galeria 1c6d440f quadro 24 | orbe com raio dourado | 32x32 | barra de Sintonia |

## 2. Folhas da galeria úteis (grade 8x8; cada folha tem 64 variações do mesmo tema, NÃO são animações em sequência: escolha quadros)

Indices: quadro k fica na coluna k%8, linha k//8. `get_image(job_id="gallery:<id>", index=k)` baixa um quadro.

| id | descrição (truncada) | tam | serve para |
|---|---|---|---|
| gallery:39caa264-6e01-5d9b-8c8e-b0b30f050d45 | Game effect sprites. Each image is one, ... | 32x32, 64 frames | 64 objetos de jogo: cristal, floco, bola de neve, estilhaço de gelo, pedra, explosão, raio, poça preta/lava, tornado, folha, sprout |
| gallery:feaf9410-fd85-5bc5-923f-b55582841dd3 | Game skill icons. Each image is one icon... | 32x32, 64 frames | ícones de habilidade: coração, escudo, espadas, gota, veneno, runas, vento, raio, relógio |
| gallery:1c6d440f-bacd-599e-9844-65b37c229c3c | Game skill icons. Each image is one icon... | 32x32, 64 frames | ícones de habilidade: chama, gelo, vento, raio, punho, tornado, onda, círculo mágico, árvore |
| gallery:01ccd7b2-b01b-561d-85a1-d2adb7424fa1 | Tiny game pickup drop icons. Each image ... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:ff953833-c654-583c-acc8-6e8ea4118d23 | horizontal, pointing to the right, seen ... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:ec585c43-97d4-5b62-9b5f-ff2676c8a017 | an enemy magic shard shot: a glowing vio... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:52e02d70-8090-5026-a09b-689a7522f5f8 | an enemy venom ball shot: a round glob o... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:4cd3543b-886e-5be1-a590-db0163456c76 | an enemy sand ball shot: a round ball of... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:f32715e7-c2e5-585f-982b-53d421641839 | an enemy lightning shot: a bright yellow... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:e313ce1e-8f9f-5d18-bd4c-b107ac6ca1a5 | an enemy holy fire shot: a round ball of... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:9bd6e62e-24f1-572c-b894-407c76b1ea5a | an enemy ice shard shot: a sharp light b... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:543855d2-c1fa-59b8-952b-0dd5fc2625ac | an enemy hellfire shot: round ball of da... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:e475b08d-386a-5b4e-b613-4308f2dc2bd6 | a small burning fire puddle on the groun... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:cd4ca798-9ff8-5689-9919-d5aabcef8062 | horizontal, pointing to the right, seen ... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:623b3eeb-4afe-573e-a617-82de8d575f73 | an enemy fireball shot: round red-orange... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:08e57d49-6676-5e5b-9b96-17e0837ac6ee | a sharp grey stone spike erupting upward... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:ebafae5a-d989-5748-a6ef-d0dd3758af4a | a crescent-shaped wind slash blade: curv... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:47018d7b-706e-5589-baca-1d692e007a06 | a small round glass potion flask with bu... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:7695d9c5-9bcd-58d3-ab91-d910a88fdcfd | one single long wooden arrow lying horiz... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:93c85dfb-bd87-55f7-9710-32d201689cbc | a small dragon fire spit glob: round bal... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:0c5342e2-c0a2-5bf1-b804-a5ab6d0c5b5f | a magic electric orb: round ball of crac... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:de930ed3-219d-5c6b-8774-82b86d29f154 | a burning flame seen from the front: tal... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:6a3f9209-f586-55fa-9414-a0a217e3bfda | a four-pointed steel ninja throwing star... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:bb04de99-620c-58cd-9416-6bbdd8c50115 | a single chunky hailstone ice ball, whit... | 16x16, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:9cbc4e00-c3bb-5d4b-b0ab-e5d08ec5e02d | a glowing magic rune circle seen from ab... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:eeac7ad0-cdb2-58aa-80f0-df7f624e0a30 | a big round grey stone boulder: rough ro... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:e751d65b-4fd6-5bed-a494-ebf1326ad97a | horizontal, pointing to the right, seen ... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:96706e99-721a-5e18-97b5-eb61e3c62858 | a magic claw slash effect: three paralle... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:7b7309d9-6b22-5606-88c8-b940a0f6e607 | horizontal, pointing to the right, seen ... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:5cc07347-af64-5142-b0b5-672575a93215 | a spinning double-bitted battle axe seen... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:7871e54e-cd02-583c-aff0-9c1461c2cc1c | a chakram throwing ring seen flat: round... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:40aca382-417d-5fac-981f-2a80c3e037da | horizontal, pointing to the right, seen ... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:acfbf5c2-4c04-54f0-8ef2-cbc12bc3867b | a wooden boomerang seen flat from above:... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:825854f3-f2e5-50e8-98b3-6c4243d020df | horizontal, pointing to the right, seen ... | 24x24, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:9463cb06-3be3-5838-a37e-ae90c422581e | a single vertical lightning bolt strikin... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:0ae7ffeb-cf69-5764-9ed8-9af070f3ad44 | a small magic whirlwind tornado seen fro... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:2f859d8c-e9a9-5eef-8868-fb8fc58a2286 | horizontal, pointing to the right, seen ... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:7713698d-a79d-5c9c-9ebd-4e5b555d8bf6 | horizontal, pointing to the right, seen ... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:891e3a57-021f-574d-97e1-320637b15a83 | horizontal, pointing to the right, seen ... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:8143c902-229e-5bcd-8adc-c10853566320 | horizontal, pointing to the right, seen ... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:66c73e43-f4e2-54ae-a720-56fe47c4e236 | horizontal, pointing to the right, seen ... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:076d6ee3-e30a-597c-881b-e74221e07ba6 | a cute magic spirit wisp: a floating bri... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:3d86b612-b8aa-5016-9697-e4d6f78b27b4 | horizontal, pointing to the right, seen ... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |
| gallery:30ea8e8a-283f-58df-b5c7-34df41ee3507 | a single fireball projectile flying to t... | 32x32, 64 frames | projéteis/efeitos (variações de pose/brilho) |

Projéteis de 16x16 (folhas 8x8): fogo 623b3eeb/e313ce1e/543855d2/93c85dfb, gelo 9bd6e62e/bb04de99, raio f32715e7, veneno 52e02d70, areia 4cd3543b, roxo ec585c43, poça de fogo e475b08d, espinho de pedra 08e57d49, lâmina de vento ebafae5a, poção 47018d7b, estrela ninja 6a3f9209.
24x24: orbe elétrico 0c5342e2, chama de frente de930ed3, círculo rúnico 9cbc4e00, pedra grande eeac7ad0, garra mágica 96706e99, machado 5cc07347, chakram 7871e54e, bumerangue acfbf5c2. 32x32: raio vertical 9463cb06, tornado 0ae7ffeb, espírito 076d6ee3, bola de fogo 30ea8e8a.

## 3. Objetos (list_objects) por tema

Baixar: o PNG com transparência fica em `https://backblaze.pixellab.ai/file/pixellab-characters/objects/<conta>/<id>/rotations/unknown.png` (url vem do get_object); ou get_object(object_id).

### Impacto / explosão / brilho

| id | descrição (truncada) | tam |
|---|---|---|
| 0307c711-4aa0-4fe7-9316-ea649c49df21 | magenta arcane star, glow... | 1dir 16x16 |
| e831b2cc-b9f6-4141-b8fc-89741a089ab8 | purple magic sparkle with... | 1dir 16x16 |
| 688c15b3-b989-4c83-811b-1cc9b745767f | white crosshair reticle, ... | 1dir 16x16 |
| 62d4f254-a770-453f-ae93-0dc123686fd6 | sharp spiky explosion sta... | 1dir 16x16 |
| 3fc4a2a5-d0db-42c2-97bf-9fcf9c19ef87 | yellow impact spark burst... | 1dir 16x16 |
| 7f3557bd-d76c-4ce1-a25c-0a18f2b08960 | glowing peach energy ball... | 1dir 16x16 |
| c177903a-a73a-4433-906b-132bb95d1a8e | magic wand with a glowing... | 1dir 20x20 |
| 24abf504-21f4-418d-9f8c-b78f0926dcd3 | red crosshair target reti... | 1dir 20x20 |
| 3c03f0e7-a34f-4fff-8b3f-b2a8a32bcc10 | purple sparkle magic star... | 1dir 20x20 |
| a2e985ef-a8b8-41b9-80a6-73509e497942 | expanding shockwave ring | 1dir 20x20 |
| e069d4af-d82d-4f63-b01e-eb994b695fd7 | exclamation mark explosio... | 1dir 20x20 |
| fe4e2416-c9b8-4137-8403-c0f54262608a | red impact burst explosio... | 1dir 20x20 |
| 6df5bc8d-a19c-4646-bf19-c1e57315c634 | glowing bubble shield, cy... | 1dir 20x20 |
| 903bcf40-520a-4aea-89a9-7e8cc8c8476e | hourglass with glowing bl... | 1dir 16x16 |
| d22dea9b-aa90-4faa-b5c0-2cb8a5dba54e | clenched red fist glowing... | 1dir 16x16 |
| def85f7a-6cc1-4177-94fb-edf1e40fd4ba | glowing eye inside a teal... | 1dir 16x16 |
| 82b741d3-35c2-4ce3-a662-e9e75db92af7 | copper coil glowing with ... | 1dir 16x16 |
| a58b9c7a-1364-4529-871a-c6f4aaa51959 | red star burst | 1dir 16x16 |
| 206755cf-4a46-460e-9c63-7f3b7534e0eb | red impact burst | 1dir 16x16 |
| e9eafadb-1aee-4f42-83ec-c2038030eea4 | white dot sparkle | 1dir 16x16 |
| 2bbd9f85-1f5c-4815-a42b-2ad9b185b0b8 | round orange fire explosi... | 1dir 64x64 |
| 5d09aae3-8792-423b-8dc0-59af717099ce | flat brown dust shockwave... | 1dir 64x64 |
| d90980be-c48f-4a8d-bdfd-2049f19b4044 | cluster of glowing purple... | 1dir 24x24 |
| 4e7518cc-4c28-4d0f-8650-94214eb954be | cluster of glowing cyan c... | 1dir 24x24 |
| 6a9ddf9b-0f71-4a35-8ba5-42ea52013374 | cluster of glowing violet... | 1dir 24x24 |
| b7bda7a0-e3db-4727-a81e-6a3a1f6c0e14 | small pool of glowing lav... | 1dir 24x24 |
| 92b0057c-484d-419c-868b-73a7a8251c55 | glowing lava crack in dar... | 1dir 24x24 |
| 7747f6a3-21bc-4962-9114-5f12f660e65c | orange mantle with glowin... | 1dir 32x32 |
| 354c7e1e-d416-432c-8f8d-af177644c138 | glowing orange and red ph... | 1dir 32x32 |
| 4fcf5a16-4cd1-42fb-9d75-84d27ba8066a | tiny glowing forest fairy... | 1dir 24x24 |
| dbe78fc1-e678-4705-9256-5597954c6937 | tiny glowing forest fairy... | 1dir 24x24 |
| 742abb0c-6b42-4836-9527-ae7e8e262e85 | cluster of glowing purple... | 1dir 32x32 |
| 84336bf3-7df9-45d7-aff5-4e513b6e4fd3 | cluster of glowing cyan c... | 1dir 32x32 |
| eece3066-b6d4-4a9f-b99c-de733c3252fc | cluster of glowing violet... | 1dir 32x32 |
| 3ee9a7bc-428d-4984-93c5-2a5b42ccc5b3 | glowing magenta magic run... | 1dir 32x32 |
| 38001bb5-59f7-4669-b666-4e65e5a23eb3 | three glowing red claw sl... | 1dir 32x32 |
| 03256be6-a4c8-44e7-b023-6599edf6e312 | glowing purple cursed cra... | 1dir 32x32 |
| 900b07dc-7435-42e7-97db-01950402d0fb | small pool of glowing lav... | 1dir 32x32 |
| 2f865815-03b2-48b9-8906-7bf9f1fe7399 | glowing lava crack in dar... | 1dir 32x32 |
| d0f32e77-8387-45e4-8e29-212a58b98750 | hourglass with glowing bl... | 1dir 32x32 |

### Fogo

| id | descrição (truncada) | tam |
|---|---|---|
| 0e9d7d54-1261-47f3-941b-116e52f9fe1e | round fireball projectile... | 1dir 20x20 |
| 82b27e1e-4385-4db1-867a-689691ff65d4 | small flame burning on a ... | 1dir 20x20 |
| 10aef075-cef5-439d-b568-275f83f9d1ef | tall campfire flame, oran... | 1dir 20x20 |
| 26945285-3843-452d-b020-625e264d5ee3 | burning ember with flame | 1dir 20x20 |
| 95c43b3a-7454-4285-a8af-fb6482657c4e | orange flame | 1dir 16x16 |
| fdf1f8c3-01ca-4046-85e1-fd3a5e6f58c8 | wall torch with a small f... | 1dir 24x24 |
| 0f8f2a8a-2af6-4cb0-926f-934a8f714f7a | wall torch with a small f... | 1dir 32x32 |
| 832eac27-ba5a-4b8f-aaa2-4522e5e7853a | small campfire with logs | 1dir 32x32 |
| d8b82a68-b4fa-46ee-853e-494e089e0ae6 | small patch of burning fl... | 1dir 32x32 |
| bc1827ab-2b6e-48c1-9f53-be41c54b7ee0 | big orange fireball with ... | 1dir 32x32 |
| c4669cf8-d28c-4729-b01d-01346357d3f6 | red and orange enemy fire... | 1dir 32x32 |
| 7570c7ff-1a33-4336-8282-7c546bfab313 | small dark red hellfire o... | 1dir 32x32 |
| 1f455a72-d8ef-4517-9725-0b19ae4e51e2 | small orange flame status... | 1dir 32x32 |
| 93ae1cd0-5747-42f7-816a-b5c14fe00148 | small flame | 1dir 32x32 |
| 93af5ede-1990-40de-aa46-b2e393f47af2 | small burning ember | 1dir 32x32 |
| 45a7b26d-23bf-458d-865a-093f93cffbd2 | big orange fireball with ... | 1dir 32x32 |
| 3a5f6c0a-62d7-44f8-a665-54f2975683dd | two burning embers spread... | 1dir 32x32 |
| 789cf413-4372-4829-bac6-ad161456f8bc | Small orange horned fire ... | 1dir 32x32 |
| 022f2db2-7a17-480e-8bee-977acc03dcab | Fireball | 8dir 32x32 |
| edc2eb43-dfca-4b2d-8d01-59ecef7f1c9f | Fireball | 8dir 32x32 |

### Gelo / água

| id | descrição (truncada) | tam |
|---|---|---|
| a6fde6b5-aef8-4fd7-bd5d-c1a7d16250b7 | simple six armed snowflak... | 1dir 16x16 |
| 778fd946-1f19-46d2-98c2-0f3d69409f46 | light blue ice star snowf... | 1dir 16x16 |
| 9440af64-21fd-4599-a2c5-0f82ef74039c | six armed light blue snow... | 1dir 20x20 |
| 7b767cad-5115-4150-9c92-b2ef986533ce | light blue ice cube block | 1dir 20x20 |
| 45b35184-fae4-4b54-8f45-217ecad3b34e | ice crystal shard, light ... | 1dir 20x20 |
| f488b54b-84a3-4c14-b5a3-1de8bff2bae3 | frozen ice block crystal | 1dir 20x20 |
| 2108ed40-6ee3-4f61-9437-712cb38615ab | golden chalice overflowin... | 1dir 16x16 |
| 9d733e56-ee6f-4872-a73e-0ab3ebbced28 | big six pointed ice cryst... | 1dir 16x16 |
| 8ed1d549-6840-49d4-ad0d-aa8ec8cce5f8 | ice block shattering into... | 1dir 16x16 |
| 8cf60ba2-6637-4b4a-80a0-6200cfd0f63c | small snow pile | 1dir 24x24 |
| c934bc31-da9a-4be5-985f-539250e1e2cd | small blue ice crystal cl... | 1dir 24x24 |
| 18747ef9-888e-427d-82e6-7569a6c4c773 | flat patch of snow on the... | 1dir 24x24 |
| 2bc08002-2d14-488e-97f4-023a264b9cbc | small flat patch of snow | 1dir 24x24 |
| 2cb6bdd2-a4c6-474f-8816-013fd181f0e6 | wide flat patch of snow | 1dir 24x24 |
| f1f9f499-1a63-4a9c-8728-f9e6c7bbf3b2 | simple wooden apprentice ... | 1dir 32x32 |
| 7415632c-fb1c-4628-9af0-c163f99daf7b | pale blue ice sword | 1dir 32x32 |
| 652c245d-8197-4eb7-83d7-b785ebcc9e34 | small snow pile | 1dir 32x32 |
| 7f745135-c7d0-417b-9468-b13a2621f2d5 | jagged blue ice crystal s... | 1dir 32x32 |
| 02e68d7f-c2e0-4ae0-ad66-ce1096b313da | small ice crystal cluster | 1dir 32x32 |
| af920378-8562-4df8-a84c-4fcbf9ce4ccf | icy blue arrow with frost... | 1dir 32x32 |
| 55a67535-27ee-4a11-b497-b8b40dbba597 | round white hailstone wit... | 1dir 32x32 |
| e6e1b648-338b-4e1e-9b6c-9772169b7dea | small ice shard projectil... | 1dir 32x32 |
| 9fbb393f-dda5-42e5-b747-b05726d3c541 | sharp blue ice spike erup... | 1dir 32x32 |
| a8db6f7a-2a78-486c-9870-672d456d1c3a | small ice crystal status ... | 1dir 32x32 |
| df3d3984-90fb-4ddc-b14d-d6f5e0495aec | small green poison bubble... | 1dir 32x32 |
| d6e155f2-d6f7-4207-91b2-2a5fa95bcd0b | big six pointed ice cryst... | 1dir 32x32 |
| 982da3a5-aa8a-483b-92fb-fb7705a06b3a | golden chalice overflowin... | 1dir 32x32 |
| ab129783-cf15-4201-940e-4ec15f0f9169 | ice block shattering into... | 1dir 32x32 |
| 6453f957-db23-403e-bd02-5d2c9dca133a | round ice bomb with a fro... | 1dir 32x32 |
| 98387114-3ef6-4604-9667-03b63cc2c09a | small snowflake | 1dir 32x32 |
| d68f17a5-64dc-4950-ae3f-71375b24eef6 | small ice cube | 1dir 32x32 |
| 5d1adabd-9c51-424b-8e79-b01e63083b4f | ring of icy blue frost mi... | 1dir 32x32 |

### Raio / vento

| id | descrição (truncada) | tam |
|---|---|---|
| 646d8394-5552-4d8d-bc07-a167099e25ca | cyan wind swirl lines, ch... | 1dir 16x16 |
| e08553b3-0b0e-4d27-bcee-0e9f53a9f9f1 | small cyan tornado, simpl... | 1dir 16x16 |
| 95ddb80b-c6db-4e44-9f3b-cdca67ea4545 | yellow lightning bolt, ch... | 1dir 16x16 |
| e0181815-2b70-4e2b-8352-11b1de93be4c | small cyan whirlwind torn... | 1dir 20x20 |
| 603648fc-1b22-4420-9142-75855bac9981 | yellow zigzag lightning b... | 1dir 20x20 |
| 5bce791c-b52e-4bfb-b833-738fc663c64e | cyan wind gust swirl line... | 1dir 20x20 |
| 0606c307-d888-4101-a794-ce76b7e9ad93 | thunder bolt, bright yell... | 1dir 20x20 |
| eadc2844-9138-4d1f-b62f-89161937b5c1 | spear with a lightning sh... | 1dir 32x32 |
| ecdea11c-4985-4838-b9be-f14362907f9e | blue electric slime blob ... | 1dir 24x24 |
| 32d4aaa9-ea4e-4b49-8011-27d10a9fe24e | blue electric slime blob ... | 1dir 24x24 |
| e0e29ab7-7075-4125-8245-d7da61852ac8 | heavy iron crossbow bolt ... | 1dir 32x32 |
| acb3d740-1574-4efc-b727-f10b87680cf9 | yellow lightning spear fl... | 1dir 32x32 |
| 14dc46b6-554b-46e7-b4e0-baeff7cf87a2 | blue electric orb crackli... | 1dir 32x32 |
| 57a74966-1dd2-45c4-8300-90636abe64ce | white crescent wind blade... | 1dir 32x32 |
| 18de934b-f7bb-4c95-a592-d1335d42a2db | short purple lightning bo... | 1dir 32x32 |
| 5481ef4d-1acd-44a7-8cf1-a96b52830ebf | small lightning bolt | 1dir 32x32 |
| f44d4907-62a0-4459-a43c-3d9510010275 | small white wind swirl | 1dir 32x32 |
| c07af9d4-5011-420f-8d1d-92bacfe33447 | yellow lightning spear fl... | 1dir 32x32 |
| 7d51a08d-fec7-4243-b1a4-2a65715a635d | jagged yellow lightning b... | 1dir 32x32 |
| 3c89dd28-e87d-42c2-9bf8-f7af2c0ec8e1 | crackling yellow electric... | 1dir 32x32 |
| 43db94f1-e820-4d57-8175-804d6ed9b822 | blue electric orb with sm... | 1dir 32x32 |
| 2d5d661b-b952-417f-b72a-30a75c2ea9bb | grey swirling tornado fun... | 1dir 32x32 |
| 6c4d0753-77cb-495b-9f09-ffbad98872d6 | teal swirling wind barrie... | 1dir 32x32 |
| 915294b2-e607-4ae7-8d59-a041672739f1 | purple arcane magic bolt ... | 1dir 32x32 |
| 20a03f08-e9bf-4fe9-a25d-7ac050df4b78 | blue electric slime blob ... | 1dir 32x32 |
| 841c2b59-1ae8-46b6-bb48-6fc2ea3e915f | blue electric slime blob ... | 1dir 32x32 |

### Folha / planta

| id | descrição (truncada) | tam |
|---|---|---|
| 656e3f46-89f1-4b05-b00f-8ba3f67b394e | green leaf, chunky | 1dir 16x16 |
| 24d14cd6-1159-495f-8e80-09567b149091 | single green leaf with a ... | 1dir 20x20 |
| add16d5e-5502-4767-8999-5e8e53890b36 | four leaf clover, green | 1dir 20x20 |
| 23135fc0-9a8e-40be-882c-8b4a9e66f5ef | green sprout with two lea... | 1dir 20x20 |
| 555a5c86-6ade-45e4-b9d0-44258f6ca847 | green four leaf clover | 1dir 16x16 |
| c0a314e7-7483-4df4-84c1-5c488c7b5670 | green leaf curled around ... | 1dir 16x16 |
| 0869e29d-5ae8-4907-8d10-5ddf50780949 | four leaf clover | 1dir 16x16 |
| b072f2c2-deb0-495b-9719-0128e66a46c8 | round green leafy bush | 1dir 24x24 |
| 985a3b3a-9a5a-47fe-851d-de13212da1b5 | small bush with tiny whit... | 1dir 24x24 |
| 8ccf2e7b-83ba-480c-b474-7b47d27f913f | small orange autumn bush | 1dir 24x24 |
| 794c0481-cdbd-4814-9baa-f63ad232b5db | small bush with blue berr... | 1dir 24x24 |
| 2ee307b9-613a-4599-bcca-67449ca27cc4 | tangle of green vines on ... | 1dir 24x24 |
| 30e753d1-3e82-4ccb-a1ff-898b6eca208d | dry brown tumbleweed bush | 1dir 24x24 |
| d48c54b7-017e-4a82-88fb-d57f60043c9c | single falling green leaf | 1dir 24x24 |
| a5cc749c-65f4-494b-a931-05e4277b84c1 | single falling red leaf | 1dir 24x24 |
| cf4e46b1-f84c-4ae5-8ffc-029d7847eb86 | green leafy druid vestmen... | 1dir 32x32 |
| e9e80bec-84a0-4117-aa47-76f6d6a7d0da | bow made of thorny vines | 1dir 32x32 |
| febb0517-2e23-455e-a933-4898f2a64405 | round green leafy bush | 1dir 32x32 |
| bc4ea931-2bac-4d6d-bc46-60b12021ed6b | small bush with tiny whit... | 1dir 32x32 |
| 33dcf1ca-d4a3-41a1-81ac-10bd764c6e0e | orange autumn bush | 1dir 32x32 |
| 838827d3-6c58-4d2a-90cb-bb9d568afbc5 | dry brown tumbleweed bush | 1dir 32x32 |
| 6c697c94-2511-488f-8b5e-52bb17cbf907 | small bush with blue berr... | 1dir 32x32 |
| 73963cd0-65d0-4b57-8e27-78bd2b501250 | tangle of green vines on ... | 1dir 32x32 |
| a216beaa-8ac3-47b9-9d14-ff5ac5b07020 | green leaf curled around ... | 1dir 32x32 |
| 9794787b-01e4-474a-972a-51c3f3543c3e | green four leaf clover | 1dir 32x32 |
| 76caa798-cc0c-40fb-89b6-7057228b9bf0 | small green leaf | 1dir 32x32 |

### Pedra / poeira / chão

| id | descrição (truncada) | tam |
|---|---|---|
| cbd85d19-5bc2-4056-bf97-cb85885c045e | round stone bullet with t... | 1dir 16x16 |
| 893e9260-0b87-4f21-95a1-99af52436564 | hourglass with sand, wood... | 1dir 16x16 |
| c3ed4e03-6a2a-4b64-926f-42bf26c64626 | small hourglass, sand fal... | 1dir 16x16 |
| b5d57e35-b23b-4a2f-a291-e9b80e316d1f | brown boulder rock | 1dir 20x20 |
| 4de34f2e-e892-4931-a8f3-8521e5541798 | pile of brown stones | 1dir 20x20 |
| 37da25f9-a6be-44b6-b139-3fad5d957dc0 | wide heavy sandstone temp... | 1dir 84x84 |
| f9d2c2be-d91d-4633-a6aa-9725b94b7dbf | wide heavy sandstone temp... | 1dir 84x84 |
| 6bd32879-2e9a-48c3-ab9d-9a23572963c3 | small golden sand dune wi... | 1dir 64x64 |
| d735371f-7ae5-495e-aab4-03597de564b2 | small sandstone pyramid w... | 1dir 64x64 |
| de3d7a56-82d6-435e-9bf2-663ba654fa40 | small dark volcanic crate... | 1dir 64x64 |
| 1abb52d4-477e-44d7-9da9-605eec9ffac0 | cracked skull with a brig... | 1dir 16x16 |
| 633e7433-aaa4-4940-9b4f-9b097e721251 | flat ring of cracked eart... | 1dir 64x64 |
| 64fd742b-a832-4cb4-991a-07457df779f9 | curved white whip crack s... | 1dir 64x64 |
| 2b63269f-23e7-4bba-99b5-388fe356299e | small grey mossy rock | 1dir 24x24 |
| 446f1baf-9167-4753-aa68-ce84d72d803f | pair of small grey pebble... | 1dir 24x24 |
| c3ed2ab3-b578-476e-a217-e67a0a08664e | round grey boulder with m... | 1dir 24x24 |
| b768f585-6e06-4de9-b0bd-09e9ab504cf5 | flat mossy rock with tiny... | 1dir 24x24 |
| 728dbd42-c831-44a5-93d2-bfbe564212f7 | small pile of stone rubbl... | 1dir 24x24 |
| d79b0687-8535-49bd-8cd6-a35ad66fc503 | scattered broken stone br... | 1dir 24x24 |
| c93abff5-cb68-4786-9b13-9365cc512adc | two tiny stone pebbles | 1dir 24x24 |
| 904a1789-129a-427c-9a53-c969329645e7 | small round barrel cactus... | 1dir 24x24 |
| 593d26db-9bfa-435d-8474-05da0201bb7c | small orange sandstone ro... | 1dir 24x24 |
| 0899be39-f78f-494b-845e-f2d61cf24dc1 | dark grey stone chunk | 1dir 24x24 |
| 1ec18a66-6aa1-4de1-92a9-d25aba47cb68 | small mossy stone lantern | 1dir 24x24 |
| f35efa62-2621-4a90-943d-6219f9f31acc | cracked clay pot | 1dir 24x24 |
| ec012c92-d10f-4638-b61c-f5d7f32cba2c | medium sandstone rock | 1dir 24x24 |
| f808e26f-fce8-4a6f-906d-64e2abffc980 | small flat sand dune ripp... | 1dir 24x24 |
| 79adcde6-3f45-4ba5-a1a0-cf992a263220 | tiny sand ripple | 1dir 24x24 |
| d35a8007-867a-432c-a825-76a175447204 | crack in sandstone floor | 1dir 24x24 |
| ffb57955-0f76-4b8a-b49a-63a6a8f23798 | old broken wooden crate | 1dir 24x24 |
| daa2af16-b411-4e9a-af4a-2ca04e4593e9 | brown stone talisman with... | 1dir 32x32 |
| 88bb3c9f-8803-4528-8c37-31b663ab67c9 | sword crackling with blue... | 1dir 32x32 |
| 31b7f9dc-5f6e-484d-a333-89b5f60c422e | grey mossy rock | 1dir 32x32 |
| a021bedc-dd4c-4a29-b741-6edb8f1e6aeb | pair of small grey stones | 1dir 32x32 |
| 846698c3-07ab-4fb3-b50b-6f0341a01b2e | big round boulder with mo... | 1dir 32x32 |
| 38daca4e-40f9-4314-a984-a792b7410f28 | short broken stone column... | 1dir 32x32 |
| eb1161f1-7e2e-4495-98ee-f742819e6a1b | broken stone column stump... | 1dir 32x32 |
| 9deef9b2-4ea4-4ddb-bacd-bca0aa693dc1 | fallen stone column lying... | 1dir 32x32 |
| 40c4ff16-86a7-4af2-9d2a-a10af2d84ad9 | small pile of stone rubbl... | 1dir 32x32 |
| 9a7cf882-3d7e-4c26-a841-5e25457b2cee | scattered broken stone br... | 1dir 32x32 |

### Escudo / proteção

| id | descrição (truncada) | tam |
|---|---|---|
| 5378f43d-93c0-4d04-89b6-33bca2d6b92d | light cyan heater shield ... | 1dir 16x16 |
| 6b2fbe74-55d6-4dd2-a009-7cd4c24af357 | cyan crystal shield, heat... | 1dir 16x16 |
| b409b591-0c0f-4e6c-9a30-676e851f3de1 | silver heater shield with... | 1dir 16x16 |
| 73f9f5d8-5266-431d-bf1a-752cb8d6ff8a | round buckler shield, lig... | 1dir 16x16 |
| 13f34418-c0d6-4d13-bd40-2f0216599fe8 | steel heater shield with ... | 1dir 16x16 |
| 82082115-224e-4d4b-8963-fb572014067b | grey iron heater shield, ... | 1dir 16x16 |
| 33289049-26b5-449a-a8a5-0bc1e74fd342 | heater shield, steel rim ... | 1dir 20x20 |
| 70c8342a-a68f-4552-b0e0-a728854a4fb5 | round shield, pale cyan a... | 1dir 20x20 |
| 53258906-f3c2-4d97-92e0-1cc82fb881b0 | round wooden shield with ... | 1dir 20x20 |
| 1c2e5307-4dbf-4670-9150-a5636520742d | golden tower shield with ... | 1dir 16x16 |
| 410d16bf-ec02-4ddf-8891-1397a7589e59 | blue shield | 1dir 16x16 |
| 8fdbc82a-a0a1-43d5-a4e6-1bd5f6f0dbc8 | blue shield | 1dir 16x16 |
| 30b05299-aed6-4ea7-ab2f-8a0e84c4a455 | golden tower shield with ... | 1dir 32x32 |
| e915c9a2-7e2d-4ae3-809c-267dc2ca5b5d | small round shield | 1dir 32x32 |
| 8dcda25f-604c-43ea-870f-5928ae69f852 | blue kite shield with a w... | 1dir 32x32 |
| 01b821a6-96b4-4a12-bd37-9b45f42d408e | shield made of pale blue ... | 1dir 32x32 |
| f1a710f0-f9d0-4b3d-9c88-de3adc7ffbd3 | round green wooden shield... | 1dir 32x32 |

### Veneno / maldição / arcano

| id | descrição (truncada) | tam |
|---|---|---|
| f6c305cc-5e1a-4bec-9bce-c4da516c7486 | green poison drop, chunky | 1dir 16x16 |
| 7f4939e0-0e59-4463-80e2-79bc3ca23b06 | two yellow stars circling... | 1dir 16x16 |
| 1e95e35e-7dbe-45e0-ae56-83b9413563bb | three small yellow stars ... | 1dir 16x16 |
| 54f478e5-6eda-4d9d-9f2b-590d322b352b | one yellow star inside a ... | 1dir 16x16 |
| bd130d43-c6ba-4242-924f-af2462a4bd3b | purple four point star sp... | 1dir 16x16 |
| 7f278863-5112-41c4-aa01-3ecb19b0024a | orange and yellow starbur... | 1dir 16x16 |
| dc4bee54-040e-45b4-b518-3d3bc40d6309 | round magic bullet flying... | 1dir 16x16 |
| 0f1eb810-5a8c-4be2-bb47-52fa2e40b316 | purple magic eight pointe... | 1dir 20x20 |
| 2e7f9afd-90fa-4e48-b3a3-fa3daf6a38dd | green poison drop with a ... | 1dir 20x20 |
| a74b69e0-9e61-47e0-b0fb-c47312d21c0a | two yellow dizzy stars ov... | 1dir 20x20 |
| 12599119-0960-4485-aad7-78592dad87b5 | purple arcane orb with sp... | 1dir 20x20 |
| d738a583-1c15-4cec-ac30-50999966af49 | green poison flask bottle | 1dir 20x20 |
| a4651136-a155-4827-91da-ed2890c7ffd5 | yellow spinning stars diz... | 1dir 20x20 |
| 573d30f5-9ea8-4d32-8fbe-467bb56a9c1b | tall starry purple archma... | 1dir 16x16 |
| 5574a90e-a193-4ee4-999a-ce7199432e01 | purple snake coiled aroun... | 1dir 16x16 |
| 39f2ca28-c89c-4dbf-a067-f6e45e1f91e7 | green poison drop | 1dir 16x16 |
| 8d4982ac-5166-45c9-9a90-7b4585b3d592 | big purple experience cry... | 1dir 16x16 |
| dffc9417-ef49-4cf2-9c33-659d9ffca411 | round purple arcane energ... | 1dir 64x64 |
| c895a207-a2ec-4db0-86de-6a4f76d40e22 | round green toxic poison ... | 1dir 64x64 |
| 73feb4f6-6e23-4a80-924b-b1b60c493d6e | flat green slime puddle o... | 1dir 64x64 |
| 0a0c9f49-44ab-41ca-a6e3-79bffad824c0 | round dark purple curse a... | 1dir 64x64 |
| 16e97608-a73e-46c9-bf14-7ef08e9edfcd | dark purple jewel shaped ... | 1dir 32x32 |
| b7f1f412-8dab-41c5-a50c-4e42b22d3dfa | purple robe with silver s... | 1dir 32x32 |
| 47f5e4b4-3040-4cb7-8a21-5180fd89a5e0 | small purple potion vial ... | 1dir 32x32 |
| 5eb118c0-6f13-4be6-90bf-5ea16e172a79 | small yellow stars spinni... | 1dir 32x32 |
| f9d6f397-f6cd-47a5-887d-34e97d0d0b92 | small round green slime b... | 1dir 24x24 |
| 15d716b5-9e12-4095-9b77-3374728a88c5 | purple cave bat flying | 1dir 24x24 |
| 39cab86e-2693-45a6-955b-9a76d94d10da | small round green slime b... | 1dir 24x24 |
| 919997ac-37b1-493b-a23b-e0789d242841 | horizontal purple title r... | 1dir 32x32 |
| 6ba05763-06a2-4a08-9563-ec1666ffacb6 | small purple arcane magic... | 1dir 32x32 |
| c579e3c9-2ab4-4323-8d28-b839014873ae | tiny pink homing magic mi... | 1dir 32x32 |
| 68b96d18-aa3e-4eef-9796-29ed0c2129c6 | small green slime glob | 1dir 32x32 |
| ef532ce9-5298-4513-b3df-119b92b9b807 | small cracked purple shie... | 1dir 32x32 |
| 21b7d90f-78d6-4d21-af2b-017f7abf4588 | purple snake coiled aroun... | 1dir 32x32 |
| cf0aa1ac-b68d-4373-8e0f-137fd8bb996e | tall starry purple archma... | 1dir 32x32 |
| d6c6db20-947d-4d6a-8687-e36a7916a3a4 | purple potion bottle with... | 1dir 32x32 |
| a7a948e2-fd00-449f-916d-43e06ffd5a6f | small green poison drop | 1dir 32x32 |
| a241935e-edaa-4516-a165-5d066aae8c85 | small purple star | 1dir 32x32 |
| 339de009-f270-471a-a01f-17bee809c894 | small blue magic sparkle | 1dir 32x32 |
| 2916ae7a-2bfd-4863-9e5c-5a346be882c3 | three small purple homing... | 1dir 32x32 |

### Setas / lâminas / punho

| id | descrição (truncada) | tam |
|---|---|---|
| 8d1dee91-1d2f-492c-ba87-6b333e1a753a | steel arrowhead dart flyi... | 1dir 16x16 |
| 46d079b3-21a0-4f13-88d3-84f99b4dceaa | three arrows fanned out, ... | 1dir 16x16 |
| c21b0442-da71-40cf-969a-483e775aefe7 | three steel daggers side ... | 1dir 16x16 |
| 24321aa3-4f7a-4110-9a7a-d3df8698d3e4 | simple steel sword diagon... | 1dir 16x16 |
| 236c040b-9453-4594-8e47-370dad0c2e75 | short broad sword diagona... | 1dir 16x16 |
| 8140ca2e-61be-43fe-a964-4468422a2455 | steel sword with crossgua... | 1dir 16x16 |
| 91db8e66-aefd-495b-9bc0-70759407b8c9 | two curved arrows chasing... | 1dir 16x16 |
| 484f4ced-d676-4178-a47e-77015036d322 | circular arrow, clockwise... | 1dir 16x16 |
| 5ccc4e20-496d-452c-aefc-255750c5f7e6 | round arrow loop, cooldow... | 1dir 16x16 |
| f636a697-9b91-47bf-b77f-7cca968e4f6a | short steel dagger pointi... | 1dir 16x16 |
| 2be2a32e-ee9b-46e8-b7e5-14fcf3427d01 | small steel knife pointin... | 1dir 16x16 |
| b7973ce7-711d-4c9d-abea-d0e507dfe2c0 | clenched fist front view,... | 1dir 16x16 |
| 4996d25f-4068-489b-9619-2c9f755c1952 | punching fist, skin color | 1dir 16x16 |
| 27ef535f-db6d-4040-a89f-75bf8312bba4 | clenched fist in grey ste... | 1dir 20x20 |
| 2dfc783a-b723-43c3-9d60-c3ecdfea2390 | steel sword diagonal with... | 1dir 20x20 |
| 8f7c6903-4b86-4316-b4b7-25322ae371f9 | three arrows side by side... | 1dir 20x20 |
| 15d2c594-f8c3-4785-ab1b-fbde4893db50 | circular refresh arrow, l... | 1dir 20x20 |
| 87936135-fe44-45cc-bbf4-f6d276455cb7 | thick cream white arrow p... | 1dir 20x20 |
| 0972400e-895f-412b-a8ed-aa3c5a7b23df | tiny knife pointing up, s... | 1dir 20x20 |
| e9369acc-5d84-4413-8b9a-e7965104c305 | punching fist, skin color | 1dir 20x20 |
| be16e380-4965-4f0e-bea7-6e810d7de048 | arrow flying right | 1dir 20x20 |
| 6c830714-c083-4023-8ad9-e634ce91cfd6 | three throwing daggers fa... | 1dir 20x20 |
| 3496baf9-76c0-48eb-b078-09c71654bf11 | two curved arrows forming... | 1dir 20x20 |
| 7ffad858-ca88-4b46-bd37-7eb83d49fa95 | short steel dagger pointi... | 1dir 20x20 |
| 3fdd96b8-6dc6-4cf5-a224-b345b4c2e8bb | deep red gash wound slash... | 1dir 16x16 |
| e23ee121-252d-454f-b5b5-f303a94732d6 | sword | 1dir 16x16 |
| af08a450-33c6-4038-9284-907a3de1c519 | stack of three arrows | 1dir 16x16 |
| 0271a936-eb75-460c-aae1-2225d94ec577 | circular blue arrow | 1dir 16x16 |
| cde2079a-b2ba-4d2f-8937-a92f57dd6a25 | red crescent sword slash | 1dir 64x64 |
| b80db0ef-1804-469b-a627-6a5c9d0871a0 | giant silver greatsword l... | 1dir 64x64 |
| 72a2702e-9e1e-4ce6-9d49-25eb8dd0c16f | crimson sword dripping bl... | 1dir 32x32 |
| a4930f31-ae64-4893-a8a4-406f5d9891b3 | simple iron knife | 1dir 32x32 |
| d44e7a1b-7971-4330-958d-b3e6bdfe7c57 | sword with a humming blue... | 1dir 32x32 |
| 3a8d3a0b-7bba-4005-96e8-75356db9f22d | wavy ritual dagger with a... | 1dir 32x32 |
| 4ccd4180-e24c-4b10-afd7-c7ee8bda1797 | dagger with a green dripp... | 1dir 32x32 |
| d2ef6126-09fd-4d81-81a8-b1125e2ccb39 | small ivory arrow pointin... | 1dir 32x32 |
| 5d972d07-f946-4cb3-9ae0-95acf93f25f7 | wooden arrow with white f... | 1dir 32x32 |
| 1ccf70d1-790f-4807-92bd-2b2e28752da0 | barbed arrow with a green... | 1dir 32x32 |
| 4d44f1ba-4a91-4e1a-a79f-b6adfbea6f04 | serrated steel dagger fly... | 1dir 32x32 |
| df11c8c4-3a1f-4e31-9d2c-cf8b715d2f0a | throwing knife with a gre... | 1dir 32x32 |

## 4. Ainda não usadas mas boas para a próxima rodada

- Folha 39caa264 (efeitos): tornado (quadro 25), raio (56), poça preta (34), neve (35), pedra (39).
- 5d09aae3/633e7433/e527413d/e36612c9/1d868889: anéis chatos que podem virar ondas de choque deitadas por tipo.
- Faltando: respingo de água, explosão de gelo, estilhaço de gelo animado, impacto genérico em sequência (quadros reais de animação). Se quiser gerar, 5 gerações bastam; neste trabalho foram gastas 0.
