# vendorportal

Read-only web inquiry over vendor master data (green screen MCS700), for the Materials group.
Project 260220-00, SOX: separates read-only vendor access from maintenance, which stays on MCS700.

| Folder      | Contents |
|-------------|----------|
| `qsqlsrc`   | Views / SQL objects (`RUNSQLSTM`) |
| `qrpglesrc` | SQLRPGLE IWS services |
| `html`      | Front end (`/www/restsrv01/htdocs/`) |
| `test`      | Verification queries |
| `docs`      | Field map, decisions, analysis scripts |

Dev: Dev3, library PRJ260220. See `docs/field_map.md` for the screen-to-file mapping.
