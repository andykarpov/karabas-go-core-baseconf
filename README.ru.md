# Ядро ZX Evolution BaseConf для Karabas Go / Mini / Mini G

[English version](README.md)

ZX Evolution (Pentevo) от NedoPC с её собственной конфигурацией FPGA, **BaseConf**, на платах семейства
Karabas Go (Xilinx Spartan-6 XC6SLX25). Работает штатный BIOS ZX Evo (ERS), 4 МБ памяти, расширенные
видеорежимы Evo, General Sound и TurboSound FM.

| Плата | Файл ядра | Видео | Звук | Накопители |
|---|---|---|---|---|
| Karabas Go | `baseconf.kg1` | VGA | I2S ЦАП (PCM5102) | физические дисководы, CF, SD |
| Karabas Mini | `baseconf.kg2` | HDMI | HDMI, аналоговый выход (sigma-delta) | CF, SD |
| Karabas Mini G | `baseconf.kg3` | HDMI | HDMI, I2S ЦАП (PCM5102) | CF, SD |

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
  уровни, General Sound (`gs.v`, ROM `roms/gs105b.rom`), TurboSound, разбор HID, контроллер физических
  дисководов (`vg93` от Firefly и его ROM микрокода) и управление частотой HDMI.
- **T80** (Daniel Wallner, Sorgelig и другие), **JT12 / JT03** (Jose Tejada), **zhdmi**
  (François Galea) и общие модули [karabas-go-modules](https://github.com/andykarpov/karabas-go-modules)
  (связь с MCU, OSD, PLL, звук, HDMI), подмодуль `modules`.

Своё в порте: `src/rtl/baseconf.v` и верхние уровни плат (переделаны из BaseConf и TS-Conf),
`baseconf_sram.v` (4 МБ в двух SRAM), `baseconf_sdram.v` (ROM и память GS в SDRAM),
`baseconf_storage.v`, `baseconf_keyboard_filter.v`, `video_fontrom.v`, а также изменения общих
исходников, перечисленные в [docs/sources.md](docs/sources.md).

## Лицензия

GPL-3.0-or-later, см. [LICENSE](LICENSE). BaseConf, JT12 и zhdmi распространяются под GPL-3.0-or-later;
ядро TS-Conf для Karabas Go — под MIT ([docs/licenses/karabas-tsconf-MIT.txt](docs/licenses/karabas-tsconf-MIT.txt)),
у T80 свой текст в стиле BSD; каждый файл исходников сохраняет свой заголовок. ROM в `src/roms` —
неизменённые файлы своих проектов (BIOS ZX Evo от NedoPC, ROM General Sound 1.05b в том виде, в каком
он поставляется с ядром TS-Conf): на них действуют их собственные условия, здесь они не перелицензируются.

## Как пользоваться

Скопируйте файл ядра своей платы на SD-карту (SD1). Ядро работает с текущей прошивкой платы,
особая прошивка не нужна. OSD открывается по Menu (Win) + Esc.

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

Shift, Ctrl и клавиши, удерживаемые при нажатии F12, выбирают, куда стартует BIOS Evo (Shift — BASIC 128,
Ctrl — BASIC 48, S — настройка CMOS, 0 — сброс выбора загрузки, ...): [docs/hotkeys.md](docs/hotkeys.md).
Раскладки джойстиков: [docs/joysticks.md](docs/joysticks.md).

## Состояние

Сборка порта **26102806**: горячие клавиши и выбор старта BIOS проверены на железе Go, Mini и Mini G;
меню BIOS, 4096 КБ памяти и игра Dune (с GS) запускались. Открытые вопросы ([docs/problems.md](docs/problems.md)):
шум AY на Mini и Mini G; физические дисководы и CF-карты на железе не проверены; сервисов AVR настоящей
Evo (виртуальные дисководы, COM-порт) нет. Сборки для Mini занимают 96-98 % слайсов.

## Сборка

ISE 14.7 (`ISE_SETTINGS`, по умолчанию `/opt/Xilinx/14.7/ISE_DS/settings64.sh`):

```sh
git submodule update --init
cd src
make go          # baseconf.kg1; mini, minig — остальные платы; make — все три
make go-report   # LUT, слайсы, timing
```

Шаги и опции те же, что в процессе karabas-forge, которым сделана сборка 26102806, поэтому из тех же
исходников получается тот же битстрим. Для плат Mini нужен ещё `make <плата>-coremode` (timing в режиме
HDMI от ядра).
