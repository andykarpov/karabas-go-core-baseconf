# Ядро ZX Evolution BaseConf для Karabas Go / Mini / Mini G

[English version](README.md)

ZX Evolution (Pentevo) от NedoPC с её собственной конфигурацией FPGA, **BaseConf**, на платах семейства
Karabas Go (Xilinx Spartan-6 XC6SLX25). Работает штатный BIOS ZX Evo (ERS), 4 МБ памяти, расширенные
видеорежимы Evo, General Sound, TurboSound FM, SAA1099, OPL2, covox / Soundrive, порт RS232 Evo (на
USB-последовательном порту платы) и TS ZiFi (ESP8266).

| Плата | Файл ядра | Видео | Звук | Накопители |
|---|---|---|---|---|
| Karabas Go | `baseconf.kg` | VGA | I2S ЦАП (PCM5102) | физические дисководы, CF, SD |
| Karabas Mini | `baseconf.kg` | HDMI | HDMI, аналоговый выход (sigma-delta) | CF, SD |
| Karabas Mini G | `baseconf.kg` | HDMI | HDMI, I2S ЦАП (PCM5102) | CF, SD |

## Авторы

Порт сделал **Сергей Лемешев** ([lordamot](https://github.com/lordamot)) в октябре 2026 года в своём
рабочем пространстве [karabas-forge](https://github.com/lordamot/karabas-forge). С его согласия порт
перенесён в этот репозиторий ([karabas-forge#1](https://github.com/lordamot/karabas-forge/issues/1)).
История порта (планы, проблемы, записи проверок) сохранена в [docs/forge](docs/forge/README.md).

Из чего собрано:

- **ZX-Evo Base Configuration** (c) NedoPC 2008-2019: пейджер, NMI и точки останова, планировщик
  памяти, порты, интерфейс SD и видеотракт Evo, из [zxevo.pentevo](https://github.com/aaydev/zxevo.pentevo)
  на `ec1405e` (`fpga/baseconf/trunk`, в `src/rtl/zxevo`); оттуда же BIOS `roms/baseconf.rom`
  (`rom/zxevo.rom`) и шрифт ATM.
- **Ядро TS-Conf для Karabas Go** ([karabas-go-core-tsconf](https://github.com/andykarpov/karabas-go-core-tsconf),
  Андрей Карпов и участники, в том числе Олег Старыченко): обвязка платы, от которой произошли верхние
  уровни, General Sound (`gs.v`, ROM `roms/gs105b.rom`), TurboSound, разбор HID, covox / Soundrive
  (`covox.vhd`), TS ZiFi с портами RS232 TS-Conf и Evo (`zifi.vhd`, UART от nandland.com), SAA1099
  (Miguel Angel Rodriguez Jodar), OPL2 на **JTOPL** (Jose Tejada), контроллер физических
  дисководов (`hrdy_fdc` с моделью VG93 из
  [FD1793_1818VG93](https://github.com/demyanenko-d/FD1793_1818VG93) и её ROM микрокода).
- **T80** (Daniel Wallner, Sorgelig и другие), **JT12 / JT03** (Jose Tejada), **zhdmi**
  (François Galea) и общие модули [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules)
  (связь с MCU, OSD, PLL, звук, HDMI), подмодуль `modules`.

Своё в порте: `src/rtl/baseconf.v` и верхние уровни плат (переделаны из BaseConf и TS-Conf),
`baseconf_sram.v` (4 МБ в двух SRAM), `baseconf_sdram.v` (ROM и память GS в SDRAM),
`baseconf_storage.v`, `baseconf_keyboard_filter.v`, `video_fontrom.v`, а также изменения общих
исходников, перечисленные в [docs/sources.md](docs/sources.md).

## Лицензия

GPL-3.0-or-later, см. [LICENSE](LICENSE). BaseConf, JT12, JTOPL и zhdmi распространяются под GPL-3.0-or-later;
ядро TS-Conf для Karabas Go — под MIT ([docs/licenses/karabas-tsconf-MIT.txt](docs/licenses/karabas-tsconf-MIT.txt)),
у T80 свой текст в стиле BSD; каждый файл исходников сохраняет свой заголовок. ROM в `src/roms` —
неизменённые файлы своих проектов (BIOS ZX Evo от NedoPC, ROM General Sound 1.05b в том виде, в каком
он поставляется с ядром TS-Conf): на них действуют их собственные условия, здесь они не перелицензируются.

## Как пользоваться

Скопируйте файл ядра своей платы на SD-карту (SD1). OSD открывается по Menu (Win) + Esc; страницам
Sound, Disks и Input нужна прошивка 26103113 или новее (старая покажет один плоский список), номерам
сборок ядра и прошивки в ERS — прошивка 26110114 или новее.

Виртуальные жёсткие диски: на странице OSD Disks поставьте **HDD** = *Image* и выберите образ (`.hdf`,
`.img`, `.vhd`, MBR с разделом FAT) как **HDF0** (IDE master; при HDD = CF card master — карта CF),
**HDF1** — slave. ERS хранит список найденных разделов в ОЗУ: после смены образов выключите и включите
плату (сброс и перезагрузка ядра ОЗУ не стирают).

| Клавиши | Действие |
|---|---|
| Menu+F6 | Covox вкл. / выкл. |
| Menu+F7 | смешивание PSG: ABC / ACB / моно |
| Menu+F8 | тип PSG: AY-3-8912 / YM2149F |
| Menu+F9 | видео: 50 Гц / 60 Гц |
| Menu+J, Menu+R | раскладка левого / правого джойстика: Kempston, Sinclair 1, Sinclair 2, Cursor, QAOPM, QAOPS, SEGA |
| Menu+P | пауза |
| F11 | NMI |
| F12 | сброс (ядра и GS) |
| только в OSD | SAA1099, OPL2, ZiFi RS232: вкл. / выкл. (выкл. ещё и глушит устройство / освобождает его порты) |
| Menu+N | HDD: карта CF / образ (IDE master) |
| Menu+F5 | выбор образа HDF0 |

Shift, Ctrl и клавиши, удерживаемые при нажатии F12, выбирают, куда стартует BIOS Evo (Shift — BASIC 128,
Ctrl — BASIC 48, S — настройка CMOS, 0 — сброс выбора загрузки, ...): [docs/hotkeys.md](docs/hotkeys.md).
Раскладки джойстиков: [docs/joysticks.md](docs/joysticks.md).

## Состояние

Сборка **26110104**: на железе Mini G проверены BIOS, сбросы (F12, 0+F12, после игр), RS232 Evo, SAA1099,
OPL2, строки версий в ERS и виртуальный HDD (детектор устройств ERS, браузер FAT32, игра, загруженная
с образа); физические дисководы работают на Go (26110102: запись, чтение, форматирование, в том числе в
турбо). Открытые вопросы ([docs/problems.md](docs/problems.md)): CF-карты на железе не проверены; TS ZiFi
(ESP8266) не проверен; Go / Mini на железе не проверялись с 26110103. Все три сборки занимают 99 % слайсов.

Сборка **26110105**: битстримы 26110104 с ERS 0.61.01 FE (pentevo `rom/zxevo_fe.rom`, 12.09.2026:
исправлена порча рамдиска при отображении информации на главном экране, режимы автозапуска перебираются
мышью, SNA в списке поддерживаемых расширений). На железе ещё не проверена.

Сборка **26110106**: то же, с одним изменённым байтом ERS (`roms/baseconf.rom` 0x581E8, `VERSION_`
в `page5/source/rst8service.a80`: `JR Z` -> `JR`): ERS больше не проверяет `FDD_EMU_PORT` и не выводит
внизу главного экрана «Incorrect FPGA zxevo_fw.bin» (эмуляция FDD на AVR здесь не используется, VG93 в FPGA).

Сборка **26110107**: битстримы 26110104 снова с ERS 0.61 из 26110104 (pentevo `rom/zxevo.rom`, без
`DOS_FE`). FE-ПЗУ из 26110105 / 26110106 монтирует TRD-образы через `dos_fe`, которому нужна FPGA с
ловушками из `fpga/base_trdemu` (`FDD_EMU_PORT`, страница `#FE`). Порт сделан на `fpga/baseconf`, поэтому
смонтированные в ERS TRD-образы там не работали. EVO-DOS обычного ПЗУ читает их сам.

Сборка **26110201**: ловушки эмуляции TR-DOS текущей BaseConf NedoPC (SVN `fpga/base_trdemu/trunk`; порт
был сделан на `fpga/baseconf/trunk`, замороженной с 2021 года) и снова ERS 0.61.01 FE (pentevo
`rom/zxevo_fe.rom`, без патча): дисководы, отмеченные в `#13BD`, не получают CS ВГ93, обращение TR-DOS к
его портам включает в окно `#0000` страницу ОЗУ `#FE` (`dos_fe` из ПЗУ, читает смонтированный в ERS
TRD-образ), возврат по `OUT (#BE)`. Также из `base_trdemu`: порт `#FF` читает последние записанные биты 4..0,
буфер чтения SD-карты (режимы с торможением 48K / 128K), порты `savelij` `#2F..#8F` убраны.
Проверено на Mini G: смонтированный в ERS TRD (`Mount A:`) загружается в TR-DOS (NEO-DOS «Nedo Emul»), `LIST`,
`SAVE` в образ. Go / Mini на железе не проверялись (на Go физические дисководы должны работать как раньше:
эмуляция забирает только дисководы, отмеченные в `#13BD`). Слайсы: Go 99 %, Mini 100 %, Mini G 100 % (map `-t 3`).

Сборка **26110301**: стрелка «вправо» USB-клавиатуры больше не сбрасывает Z80 (Mini G 26110201: машина
перезапускалась в ПЗУ 128K, а с зажатой клавишей — в его самотест клавиатуры). F12 ловилось комбинационным
сравнением байтов клавиш (`== 8'h45`) перед асинхронным сбросом `resetter`; пока байт клавиши меняется 00 <-> 4F
(«вправо» = 45 плюс биты 1 и 3), сравнение могло на мгновение пропустить 45, в зависимости от трассировки сборки.
Клавиши сброса (`kb_reset`, `btn_reset_n`) теперь регистрируются на `clk_bus` в топах плат, а запрос сброса
`resetter` — на частоте процессора (асинхронным остался только `locked`). Проверено на Mini G: «вправо» в ERS
(10 раз) и в редакторе 128 BASIC, F12. Go / Mini на железе не проверялись.

## Сборка

ISE 14.7 (`ISE_SETTINGS`, по умолчанию `/opt/Xilinx/14.7/ISE_DS/settings64.sh`):

```sh
git submodule update --init
cd src
make go          # битстрим Go в baseconf.kg; mini, minig — остальные платы; make — все три
make go-report   # LUT, слайсы, timing
```

`make_core.py` — ссылка на соседний репозиторий karabas-go-tools (склонируйте его рядом). Сборка 26102806
из karabas-forge — коммит `50177ec`; с тех пор исходники изменились ([docs/sources.md](docs/sources.md)).
Для плат Mini нужен ещё `make <плата>-coremode` (timing в режиме
HDMI от ядра).
