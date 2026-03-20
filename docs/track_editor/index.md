# Track Editor — Research Index

Research notes for building a Godot 4 in-game/editor track editor tool.

## Documents

| File | What it covers |
|---|---|
| [godot_ui_fundamentals.md](godot_ui_fundamentals.md) | Control nodes, containers, anchors, themes, UI animation |
| [editor_plugins.md](editor_plugins.md) | `@tool`, EditorPlugin, custom docks, inspector plugins, undo/redo |

## Key Resource Links

### Official Docs
- UI overview: https://docs.godotengine.org/en/4.4/tutorials/ui/index.html
- GUI skinning / themes: https://docs.godotengine.org/en/4.4/tutorials/ui/gui_skinning.html
- Theme editor: https://docs.godotengine.org/en/4.4/tutorials/ui/gui_using_theme_editor.html
- `@tool` scripts: https://docs.godotengine.org/en/4.4/tutorials/plugins/running_code_in_the_editor.html
- Making plugins: https://docs.godotengine.org/en/4.4/tutorials/plugins/editor/making_plugins.html
- EditorPlugin API: https://docs.godotengine.org/en/stable/classes/class_editorplugin.html
- Inspector plugins: https://docs.godotengine.org/en/4.4/tutorials/plugins/editor/inspector_plugins.html
- Undo/Redo: https://docs.godotengine.org/en/4.4/tutorials/plugins/editor/undo_redo.html

### Articles
- Febucci — Godot 4 UI core concepts: https://blog.febucci.com/2024/11/godots-ui-tutorial-part-one/
- Kodeco — Extending the editor with plugins: https://www.kodeco.com/44259876-extending-the-editor-with-plugins-in-godot
- Uhiyama-lab — Theme system: https://uhiyama-lab.com/en/notes/godot/theme-system-unified-ui/
- Uhiyama-lab — EditorPlugin workflow (Feb 2026): https://uhiyama-lab.com/en/notes/godot/editor-plugin-workflow/
- KidsCanCode — Godot 4 UI recipes: https://kidscancode.org/godot_recipes/4.x/ui/index.html
- Gravity Ace — building a level editor: https://gravityace.com/devlog/building-a-level-editor/

### YouTube Playlists (transcripts in `transcripts/`)
| Channel | Playlist | URL |
|---|---|---|
| GDQuest | Godot User Interface Tutorials (Godot 3) | https://www.youtube.com/playlist?list=PLhqJJNjsQ7KGXNbfsUHJbb5-s2Tujtjt4 |
| StayAtHomeDev | Godot User Interface Tutorials | https://www.youtube.com/playlist?list=PLEHvj4yeNfeGiG6ZJXDymk5dYBAjCGiwe |
| PlayWithFurcifer | Godot Tutorials | https://www.youtube.com/playlist?list=PLIPN1rqO-3eGXTDiptZgPnXTObQ4vOQhG |
| KidsCanCode | Godot 4 Recipes | https://www.youtube.com/playlist?list=PLsk-HSGFjnaHmL6Wt4ihrxyASbM6kxCTc |

To fetch more transcripts: `bash fetch_transcripts.sh "<playlist_url>"`

### Reference Plugins
- Cyclops Level Builder (3D block editor plugin, open source): https://github.com/blackears/cyclopsLevelBuilder
- awesome-godot: https://github.com/godotengine/awesome-godot
- godot-4-awesome-help (curated YT links): https://github.com/mogoh/godot-4-awesome-help

## Recommended Learning Path

For building the track editor specifically:

1. **Start with `@tool`** — understand `Engine.is_editor_hint()` and live property previews
2. **Read Making Plugins docs** — plugin.cfg, EditorPlugin lifecycle, `_enter_tree`/`_exit_tree`
3. **Study EditorPlugin undo/redo** — critical for any editor; covered in Kodeco article + docs
4. **Review Cyclops Level Builder source** — real-world complex 3D editor plugin reference
5. **UI fundamentals** — Control nodes, containers, anchors for the editor's own UI panels
