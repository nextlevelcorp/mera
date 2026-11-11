# Localisation
- English is the source language; Turkish (tr) and Spanish (es) ship in the MVP.
- All strings go in `game/locale/translations.csv` (columns `keys,en,tr,es`). A key missing in any language fails `test_localisation.gd`.
- Species carry the scientific name plus local common names per language.
- Source strings, code and comments stay English even when the chat is Turkish.
