#!/usr/bin/env python3
"""Visual picker for locally installed Syna themes."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import threading
import tomllib
import gi

gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GdkPixbuf, Gio, GLib

GLib.set_prgname('syna-theme-picker')
sys.dont_write_bytecode = True
ROOT = Path.home() / '.config/themes'
SCRIPTS = Path.home() / '.local/bin/rice'
spec = importlib.util.spec_from_file_location('theme_engine', SCRIPTS / 'syna-theme-engine.py')
engine = importlib.util.module_from_spec(spec)
spec.loader.exec_module(engine)
spec2 = importlib.util.spec_from_file_location('theme_custom', SCRIPTS / 'syna-theme-customize.py')
custom = importlib.util.module_from_spec(spec2)
spec2.loader.exec_module(custom)
spec3 = importlib.util.spec_from_file_location('theme_creator', SCRIPTS / 'syna-theme-create.py')
creator = importlib.util.module_from_spec(spec3)
spec3.loader.exec_module(creator)
spec4 = importlib.util.spec_from_file_location('theme_ai', SCRIPTS / 'syna-theme-ai.py')
ai = importlib.util.module_from_spec(spec4)
spec4.loader.exec_module(ai)


def title(name):
    return custom.display_name(name)


def read_name(path):
    return path.read_text().strip() if path.is_file() else ''


class Picker(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='io.adept.syna.themes', flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.window = None
        self.editor = None
        self.busy = False

    def do_activate(self):
        if self.window is None:
            self.window = Gtk.ApplicationWindow(application=self, title='Syna Themes')
            self.window.set_default_size(860, 740)
            header = Gtk.HeaderBar(title='Syna Themes', show_close_button=True)
            self.window.set_titlebar(header)
            self.css = Gtk.CssProvider()
            Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), self.css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            self.window.connect('delete-event', lambda *_: self.busy)
            self.window.connect('key-press-event', self.keypress)
            outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin=18)
            self.window.add(outer)
            heading = Gtk.Label(xalign=0)
            heading.set_markup('<big><b>Choose your desktop theme</b></big>')
            outer.pack_start(heading, False, False, 0)
            self.status = Gtk.Label(xalign=0, wrap=True)
            outer.pack_start(self.status, False, False, 0)
            bar = Gtk.Box(spacing=10)
            self.restore = Gtk.Button(label='Restore previous')
            self.restore.connect('clicked', lambda *_: self.apply('--previous'))
            bar.pack_start(self.restore, False, False, 0)
            removed = Gtk.Button(label='Recently removed')
            removed.connect('clicked', lambda *_: self.show_removed())
            bar.pack_start(removed, False, False, 0)
            create = Gtk.Button(label='Create from wallpaper')
            create.connect('clicked', lambda *_: self.create_from_wallpaper())
            bar.pack_start(create, False, False, 0)
            outer.pack_start(bar, False, False, 0)
            scroll = Gtk.ScrolledWindow()
            scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
            self.cards = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE)
            self.cards.set_min_children_per_line(2)
            self.cards.set_max_children_per_line(3)
            self.cards.set_column_spacing(10)
            self.cards.set_row_spacing(10)
            scroll.add(self.cards)
            outer.pack_start(scroll, True, True, 0)
            outer.pack_start(Gtk.Label(label='Previews show wallpaper and palette. Click a theme to apply it.', xalign=0), False, False, 0)
            self.refresh()
        self.window.show_all()
        self.window.present()

    def keypress(self, widget, event):
        if event.keyval == Gdk.KEY_Escape and not self.busy:
            self.window.destroy()
            self.window = None
            return True
        return False

    def refresh(self, message=None):
        current = read_name(ROOT / 'current.name')
        colors = engine.palette(ROOT / current / 'colors.toml', ROOT / '.overrides' / (current + '.toml'))
        self.css.load_from_data(('window, dialog, notebook, notebook > stack, notebook > header, list, row, headerbar, viewport, flowbox { background: ' + colors['background'] + '; color: ' + colors['foreground'] + '; } button { background: ' + colors['background'] + '; color: ' + colors['foreground'] + '; border: 1px solid ' + colors['color8'] + '; border-radius: 8px; padding: 8px; } button:hover { border-color: ' + colors['accent'] + '; } label { color: ' + colors['foreground'] + '; } list.wallpaper-list row { border: 2px solid transparent; border-radius: 8px; margin: 3px; } list.wallpaper-list row:selected { background: ' + colors['selection_background'] + '; border-color: ' + colors['accent'] + '; } list.wallpaper-list row:selected label { color: ' + colors['selection_foreground'] + '; }').encode())
        previous = read_name(ROOT / 'previous/.theme-name')
        self.status.set_text(message or ('Current theme: ' + title(current)))
        self.restore.set_label('Restore previous' + (' · ' + title(previous) if previous else ''))
        self.restore.set_sensitive(bool(previous) and not self.busy)
        for child in self.cards.get_children():
            self.cards.remove(child)
        for directory in sorted(ROOT.iterdir()):
            name = directory.name
            if name.startswith('.') or name in {'current', 'previous', 'next-theme', 'templates', 'backgrounds'} or directory.is_symlink() or not directory.is_dir():
                continue
            try:
                colors = engine.palette(directory / 'colors.toml', ROOT / '.overrides' / (name + '.toml'))
                self.cards.add(self.card(name, directory, colors, current))
            except (OSError, ValueError) as error:
                self.cards.add(Gtk.Label(label=f'{title(name)}: invalid palette', tooltip_text=str(error)))
        self.cards.show_all()

    def card(self, name, directory, colors, current):
        button = Gtk.Button()
        button.connect('clicked', lambda *_: self.apply(name))
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7, margin=6)
        button.add(box)
        images = custom.wallpapers(name)
        saved = custom.selected(name)
        if saved in images:
            images.insert(0, saved)
        wallpaper = ROOT / 'current/background'
        if name == current and wallpaper.is_file():
            images.insert(0, wallpaper)
        preview = Gtk.Image()
        preview.set_size_request(225, 112)
        if images:
            try:
                preview.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(images[0]), 225, 112, True))
            except GLib.Error:
                preview.set_from_icon_name('image-missing', Gtk.IconSize.DIALOG)
        box.pack_start(preview, False, False, 0)
        sample = Gtk.Label(xalign=0)
        sample.set_markup(f'<span background="{colors["background"]}" foreground="{colors["foreground"]}">  Desktop text  <span foreground="{colors["accent"]}">Accent</span>  </span>')
        box.pack_start(sample, False, False, 0)
        swatches = Gtk.Label(xalign=0)
        swatches.set_markup(''.join(f'<span background="{colors[key]}">     </span>' for key in ['background', 'foreground', 'accent', 'color2', 'color3', 'color5']))
        box.pack_start(swatches, False, False, 0)
        label = title(name) + ('  ✓ Current' if name == current else '')
        original = name.replace('-', ' ').title()
        if title(name) != original:
            label += '\nOriginal: ' + original
        if (ROOT / '.overrides' / (name + '.toml')).exists():
            label += '\nPersonal colors'
        box.pack_start(Gtk.Label(label=label, xalign=0), False, False, 0)
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        card.pack_start(button, True, True, 0)
        edit = Gtk.Button(label='Customize')
        edit.connect('clicked', lambda *_: self.customize(name))
        actions = Gtk.Box(spacing=5)
        actions.pack_start(edit, True, True, 0)
        rename = Gtk.Button(label='Rename')
        rename.connect('clicked', lambda *_: self.rename_theme(name))
        actions.pack_start(rename, False, False, 0)
        card.pack_start(actions, False, False, 0)
        duplicate = Gtk.Button(label='Duplicate')
        duplicate.connect('clicked', lambda *_: self.duplicate_theme(name))
        more = Gtk.Box(spacing=5)
        more.pack_start(duplicate, True, True, 0)
        if name != current:
            remove = Gtk.Button(label='Remove')
            remove.connect('clicked', lambda *_: self.remove_theme(name))
            more.pack_start(remove, True, True, 0)
        card.pack_start(more, False, False, 0)
        return card

    def create_from_wallpaper(self):
        if self.busy: return
        chooser = Gtk.FileChooserDialog(title='Create theme from wallpaper', transient_for=self.window, action=Gtk.FileChooserAction.OPEN)
        chooser.add_buttons('Cancel', Gtk.ResponseType.CANCEL, 'Generate palette', Gtk.ResponseType.OK)
        filt=Gtk.FileFilter(); filt.set_name('Images')
        for mime in ['image/png','image/jpeg','image/webp','image/avif']: filt.add_mime_type(mime)
        chooser.add_filter(filt)
        response=chooser.run(); filename=chooser.get_filename(); chooser.destroy()
        if response != Gtk.ResponseType.OK: return
        self.busy=True; self.window.set_sensitive(False)
        self.status.set_text('Extracting wallpaper colors locally…')
        def worker():
            try: colors=creator.extract(Path(filename))
            except Exception as error: GLib.idle_add(self.creator_preview, filename, None, str(error))
            else: GLib.idle_add(self.creator_preview, filename, colors, None)
        threading.Thread(target=worker,daemon=True).start()

    def creator_preview(self, filename, colors, error, existing_name=None):
        self.busy=False; self.window.set_sensitive(True)
        if error:
            self.status.set_text('Could not read image: '+error); return False
        dialog=Gtk.Dialog(title=('Refine '+title(existing_name) if existing_name else 'Theme Creator · Wallpaper'), transient_for=self.window, modal=True)
        dialog.set_default_size(620,600)
        dialog.add_button('Cancel',Gtk.ResponseType.CANCEL)
        save=dialog.add_button('Save changes' if existing_name else 'Save new theme',Gtk.ResponseType.OK)
        copy_button=dialog.add_button('Save as a copy',Gtk.ResponseType.APPLY) if existing_name else None
        content=dialog.get_content_area();content.set_spacing(10);content.set_border_width(16)
        content.pack_start(Gtk.Label(label='Local extraction · Optional AI refinement on this PC',xalign=0),False,False,0)
        image=Gtk.Image()
        try:image.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(filename,480,180,True))
        except GLib.Error:pass
        content.pack_start(image,False,False,0)
        name=Gtk.Entry(text=(title(existing_name)+' Copy' if existing_name else Path(filename).stem.replace('_',' ').replace('-',' ').title()),max_length=60)
        content.pack_start(Gtk.Label(label='Name for a new copy' if existing_name else 'Theme name',xalign=0),False,False,0)
        content.pack_start(name,False,False,0)
        preview=Gtk.Label(xalign=0);content.pack_start(preview,False,False,0)
        swatches=Gtk.Label(xalign=0)
        swatches.set_markup(''.join(f'<span background="{colors["color"+str(i)]}">    </span>' for i in range(16)))
        content.pack_start(swatches,False,False,0)
        controls={}
        status=Gtk.Label(xalign=0,wrap=True)
        def update(*_):
            for key,control in controls.items():
                c=control.get_rgba();colors[key]=creator.hexcolor((c.red,c.green,c.blue))
            colors['cursor']=colors['foreground'];colors['border_top']=colors['accent'];colors['border_bottom']=colors['foreground']
            colors['selection_background']=colors['accent']
            colors['selection_foreground']=max(['#000000','#ffffff'],key=lambda c:creator.contrast(c,colors['accent']))
            preview.set_markup(f'<span background="{colors["background"]}" foreground="{colors["foreground"]}">\n   Desktop text    <span foreground="{colors["accent"]}">Accent</span>   \n</span>')
            swatches.set_markup(''.join(f'<span background="{colors["color"+str(i)]}">    </span>' for i in range(16)))
            try:creator.validate_colors(colors)
            except ValueError as problem:
                status.set_text(str(problem));save.set_sensitive(False)
                if copy_button is not None:copy_button.set_sensitive(False)
            else:
                hint='Save changes updates this theme; Save as a copy keeps the original.' if existing_name else 'Saving does not change your current theme.'
                status.set_text(f'Text contrast {creator.contrast(colors["foreground"],colors["background"]):.1f}:1. '+hint)
                save.set_sensitive(True)
                if copy_button is not None:copy_button.set_sensitive(True)
        for key,label in [('background','Background'),('foreground','Text'),('accent','Accent')]:
            row=Gtk.Box(spacing=10);row.pack_start(Gtk.Label(label=label,xalign=0),True,True,0)
            rgba=Gdk.RGBA();rgba.parse(colors[key]);control=Gtk.ColorButton(rgba=rgba,use_alpha=False,title=label)
            controls[key]=control;control.connect('color-set',update);row.pack_start(control,False,False,0)
            content.pack_start(row,False,False,0)
        content.pack_start(Gtk.Label(label='Accent colors from this image — click one to preview',xalign=0),False,False,0)
        choices=Gtk.Box(spacing=6)
        for candidate in creator.accent_choices(Path(filename)):
            button=Gtk.Button()
            swatch=Gtk.Label()
            text=max(['#000000','#ffffff'],key=lambda c:creator.contrast(c,candidate))
            swatch.set_markup(f'<span background="{candidate}" foreground="{text}">  {candidate}  </span>')
            button.add(swatch)
            def choose(widget,value=candidate):
                adjusted=creator.readable(value,colors['background'],3)
                rgba=Gdk.RGBA();rgba.parse(adjusted);controls['accent'].set_rgba(rgba);update()
            button.connect('clicked',choose);choices.pack_start(button,False,False,0)
        content.pack_start(choices,False,False,0)
        ai_panel=Gtk.Expander(label='Refine with local AI (optional)')
        ai_box=Gtk.Box(orientation=Gtk.Orientation.VERTICAL,spacing=8,margin=8)
        ai_panel.add(ai_box)
        ai_box.pack_start(Gtk.Label(label='A resized image and your instructions go to Ollama on this PC.\nThe model unloads after generation; nothing is applied automatically.',xalign=0,wrap=True),False,False,0)
        model=Gtk.ComboBoxText()
        ai_box.pack_start(model,False,False,0)
        prompt=Gtk.Entry(placeholder_text='e.g. Emphasize crimson; keep the background dark',max_length=2000)
        ai_box.pack_start(prompt,False,False,0)
        actions=Gtk.Box(spacing=8)
        refine=Gtk.Button(label='Refine palette');refine.set_sensitive(False)
        undo_ai=Gtk.Button(label='Undo AI refinement');undo_ai.set_sensitive(False)
        actions.pack_start(refine,False,False,0);actions.pack_start(undo_ai,False,False,0)
        ai_box.pack_start(actions,False,False,0)
        ai_status=Gtk.Label(label='Open this section to find installed vision models.',xalign=0,wrap=True)
        ai_box.pack_start(ai_status,False,False,0)
        state={'alive':True,'loading':False,'history':[]}
        dialog.connect('destroy',lambda *_:state.update(alive=False))
        def model_result(names,error):
            if not state['alive']:return False
            state['loading']=False
            model.remove_all()
            for item in names:model.append_text(item)
            if names:model.set_active(0)
            refine.set_sensitive(bool(names))
            ai_status.set_text(error or ('Choose a model and describe your changes.' if names else 'No local vision models installed. Local extraction still works.'))
            return False
        def discover(widget,param):
            if not widget.get_expanded() or state['loading'] or model.get_active_text():return
            state['loading']=True;ai_status.set_text('Checking local Ollama…')
            def worker():
                try:names=ai.models()
                except Exception as error:GLib.idle_add(model_result,[],str(error))
                else:GLib.idle_add(model_result,names,None)
            threading.Thread(target=worker,daemon=True).start()
        ai_panel.connect('notify::expanded',discover)
        def show_palette(palette):
            colors.clear();colors.update(palette)
            for key,control in controls.items():
                rgba=Gdk.RGBA();rgba.parse(colors[key]);control.set_rgba(rgba)
            update()
        def undo_refinement(*_):
            if state['history']:show_palette(state['history'].pop())
            undo_ai.set_sensitive(bool(state['history']));ai_status.set_text('Previous draft palette restored.')
        undo_ai.connect('clicked',undo_refinement)
        def refine_done(palette,error,before):
            self.busy=False
            if not state['alive']:return False
            dialog.set_sensitive(True)
            if error:ai_status.set_text('AI could not refine this palette: '+error+' Your draft is unchanged.')
            else:
                state['history'].append(before);show_palette(palette);undo_ai.set_sensitive(True)
                ai_status.set_text('AI suggestion previewed. Adjust it, undo, or save as a new theme.')
            return False
        def refine_clicked(*_):
            if not prompt.get_text().strip():ai_status.set_text('Describe the changes you want.');return
            before=dict(colors);instruction=prompt.get_text();chosen=model.get_active_text()
            self.busy=True;dialog.set_sensitive(False);ai_status.set_text('Generating locally… model loading may take a moment.')
            def worker():
                try:palette=ai.refine(Path(filename),instruction,before,chosen,creator)
                except Exception as error:GLib.idle_add(refine_done,None,str(error),before)
                else:GLib.idle_add(refine_done,palette,None,before)
            threading.Thread(target=worker,daemon=True).start()
        refine.connect('clicked',refine_clicked)
        content.pack_start(ai_panel,False,False,0)
        content.pack_start(status,False,False,0);update()
        def complete(result,error):
            self.busy=False;dialog.set_sensitive(True)
            if error:status.set_text('Could not save theme: '+error)
            else:dialog.destroy();self.refresh(('Saved changes to '+title(result)+'.') if existing_name and result==existing_name else ('Created '+title(result)+'. Click its card to apply it.'))
            return False
        def respond(widget,response):
            if self.busy:return
            if response not in (Gtk.ResponseType.OK,Gtk.ResponseType.APPLY):dialog.destroy();return
            update()
            if not save.get_sensitive():return
            label=name.get_text();palette=dict(colors)
            self.busy=True;dialog.set_sensitive(False)
            def worker():
                try:
                    if existing_name and response==Gtk.ResponseType.OK:
                        result=creator.save_existing(existing_name,palette,custom,engine)
                    else:
                        result=creator.create(label,Path(filename),palette,custom,engine)
                except Exception as error:GLib.idle_add(complete,None,str(error))
                else:GLib.idle_add(complete,result,None)
            threading.Thread(target=worker,daemon=True).start()
        dialog.connect('response',respond);dialog.connect('delete-event',lambda *_:self.busy)
        dialog.show_all()
        if existing_name:ai_panel.set_expanded(True)
        return False

    def show_removed(self):
        dialog = Gtk.Dialog(title='Recently removed themes', transient_for=self.window, modal=True)
        dialog.set_default_size(620, 420)
        dialog.add_button('Close', Gtk.ResponseType.CLOSE)
        content = dialog.get_content_area(); content.set_border_width(16); content.set_spacing(10)
        content.pack_start(Gtk.Label(label='Restore a theme without changing your current desktop.', xalign=0), False, False, 0)
        scroll = Gtk.ScrolledWindow(); scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        rows = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        scroll.add(rows); content.pack_start(scroll, True, True, 0)
        status = Gtk.Label(xalign=0, wrap=True); content.pack_start(status, False, False, 0)
        def refresh():
            for row in rows.get_children(): rows.remove(row)
            entries = custom.removed_themes()
            if not entries: rows.pack_start(Gtk.Label(label='No removed themes to restore.'), False, False, 0)
            for archive, data in entries:
                row = Gtk.Box(spacing=12)
                row.pack_start(Gtk.Label(label=data['name'], xalign=0), True, True, 0)
                button = Gtk.Button(label='Restore')
                button.connect('clicked', restore, archive)
                row.pack_start(button, False, False, 0)
                delete = Gtk.Button(label='Delete permanently')
                delete.get_style_context().add_class('destructive-action')
                delete.connect('clicked', delete_archive, archive, data['name'])
                row.pack_start(delete, False, False, 0)
                rows.pack_start(row, False, False, 0)
            rows.show_all()
        def delete_archive(button, archive, name):
            confirm = Gtk.Dialog(title='Permanently delete ' + name + '?', transient_for=dialog, modal=True)
            confirm.add_button('Cancel', Gtk.ResponseType.CANCEL)
            delete = confirm.add_button('Delete permanently', Gtk.ResponseType.OK)
            delete.get_style_context().add_class('destructive-action')
            delete.set_sensitive(False)
            confirm.set_default_response(Gtk.ResponseType.CANCEL)
            area = confirm.get_content_area(); area.set_border_width(16); area.set_spacing(12)
            area.pack_start(Gtk.Label(label='This permanently erases the archived theme, colors, and wallpapers.\nIt cannot be restored through the picker.', xalign=0, wrap=True), False, False, 0)
            area.pack_start(Gtk.Label(label='Type exactly: ' + name, xalign=0, selectable=True), False, False, 0)
            entry = Gtk.Entry()
            entry.connect('changed', lambda widget: delete.set_sensitive(widget.get_text() == name))
            area.pack_start(entry, False, False, 0)
            def respond(widget, response):
                if response == Gtk.ResponseType.OK:
                    try:
                        custom.delete_permanently(archive, entry.get_text())
                    except (OSError, ValueError, KeyError) as error:
                        status.set_text('Could not delete: ' + str(error))
                    else:
                        status.set_text('Permanently deleted ' + name + '.')
                    refresh()
                confirm.destroy()
            confirm.connect('response', respond)
            confirm.show_all(); entry.grab_focus()
        def restore(button, archive):
            try:
                name = custom.restore_theme(archive)
            except (OSError, ValueError, KeyError) as error:
                status.set_text('Could not restore: ' + str(error)); return
            status.set_text('Restored ' + title(name) + '. Choose its card to apply it.')
            refresh(); self.refresh()
        refresh()
        dialog.connect('response', lambda *_: dialog.destroy())
        dialog.show_all()

    def remove_theme(self, name):
        if read_name(ROOT / 'current.name') == name:
            self.status.set_text('Switch to another theme before removing this one.')
            return
        dialog = Gtk.MessageDialog(transient_for=self.window, modal=True,
                                   message_type=Gtk.MessageType.WARNING,
                                   buttons=Gtk.ButtonsType.NONE,
                                   text='Remove “' + title(name) + '”?')
        text = 'This removes the theme from the picker, along with its personal colors and wallpaper collection. Files will be archived for recovery.'
        if read_name(ROOT / 'previous/.theme-name') == name:
            text += '\n\nThis is also your previous theme. Its Restore previous option will be removed.'
        dialog.format_secondary_text(text)
        dialog.add_button('Cancel', Gtk.ResponseType.CANCEL)
        dialog.add_button('Remove theme', Gtk.ResponseType.OK)
        dialog.set_default_response(Gtk.ResponseType.CANCEL)
        def respond(widget, response):
            dialog.destroy()
            if response != Gtk.ResponseType.OK: return
            try:
                custom.remove_theme(name)
            except (OSError, ValueError) as error:
                self.refresh('Could not remove theme: ' + str(error))
            else:
                self.refresh('Theme removed. Your current theme is unchanged.')
        dialog.connect('response', respond)
        dialog.show_all()

    def duplicate_theme(self, name):
        dialog = Gtk.Dialog(title='Duplicate ' + title(name), transient_for=self.window, modal=True)
        dialog.add_buttons('Cancel', Gtk.ResponseType.CANCEL, 'Create copy', Gtk.ResponseType.OK)
        dialog.set_default_response(Gtk.ResponseType.OK)
        content = dialog.get_content_area(); content.set_border_width(16); content.set_spacing(10)
        content.pack_start(Gtk.Label(label='Name for your independent copy', xalign=0), False, False, 0)
        entry = Gtk.Entry(text=title(name) + ' Copy', activates_default=True, max_length=60)
        content.pack_start(entry, False, False, 0)
        note = Gtk.Label(label='Copies colors and wallpapers. Your current theme stays active.', wrap=True, xalign=0)
        content.pack_start(note, False, False, 0)
        def complete(result, error):
            self.busy = False
            self.cards.set_sensitive(True)
            dialog.set_sensitive(True)
            if error:
                self.refresh()
                note.set_text(error)
            else:
                dialog.destroy()
                self.refresh('Created ' + title(result) + '. Choose its card to apply or customize it.')
            return False
        def respond(widget, response):
            if self.busy: return
            if response != Gtk.ResponseType.OK:
                dialog.destroy(); return
            label = entry.get_text()
            self.busy = True; self.cards.set_sensitive(False); self.restore.set_sensitive(False)
            dialog.set_sensitive(False)
            def worker():
                try:
                    result = custom.duplicate(name, label)
                except (OSError, ValueError) as error:
                    GLib.idle_add(complete, None, str(error))
                else:
                    GLib.idle_add(complete, result, None)
            threading.Thread(target=worker, daemon=True).start()
        dialog.connect('response', respond)
        dialog.connect('delete-event', lambda *_: self.busy)
        dialog.show_all(); entry.grab_focus(); entry.select_region(0, -1)

    def rename_theme(self, name):
        dialog = Gtk.Dialog(title='Change display name', transient_for=self.window, modal=True)
        dialog.add_buttons('Cancel', Gtk.ResponseType.CANCEL, 'Save name', Gtk.ResponseType.OK)
        dialog.set_default_response(Gtk.ResponseType.OK)
        content = dialog.get_content_area()
        content.set_border_width(16)
        content.set_spacing(10)
        original = name.replace('-', ' ').title()
        content.pack_start(Gtk.Label(label='Original theme: ' + original, xalign=0), False, False, 0)
        content.pack_start(Gtk.Label(label='Your display name', xalign=0), False, False, 0)
        entry = Gtk.Entry(text=title(name), activates_default=True, max_length=60)
        entry.set_width_chars(32)
        content.pack_start(entry, False, False, 0)
        note = Gtk.Label(label='This name appears in the picker and desktop theme labels.\nThe original theme, colors, and wallpapers stay intact.\nTerminal commands still use: syna-theme-set ' + name, wrap=True, xalign=0)
        content.pack_start(note, False, False, 0)
        def respond(widget, response):
            if response == Gtk.ResponseType.OK:
                try:
                    label = custom.rename(name, entry.get_text())
                except (OSError, ValueError) as error:
                    note.set_text(str(error)); return
                self.refresh('Theme renamed to ' + label + '.')
            dialog.destroy()
        dialog.connect('response', respond)
        dialog.show_all()
        entry.grab_focus()
        entry.select_region(0, -1)

    def customize(self, name):
        dialog = Gtk.Dialog(title=title(name) + ' · Customize', transient_for=self.window, modal=True)
        self.editor = dialog
        dialog.connect('destroy', lambda *_: setattr(self, 'editor', None))
        dialog.set_default_size(720, 650)
        dialog.add_button('Close', Gtk.ResponseType.CLOSE)
        content = dialog.get_content_area()
        content.set_spacing(10)
        content.set_border_width(16)
        tabs = Gtk.Notebook()
        tabs.set_scrollable(True)
        content.pack_start(tabs, True, True, 0)
        status = Gtk.Label(xalign=0, wrap=True)
        content.pack_start(status, False, False, 0)
        colors = engine.palette(ROOT / name / 'colors.toml', ROOT / '.overrides' / (name + '.toml'))
        controls = {}
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin=12)
        preview = Gtk.Label(xalign=0)
        preview.set_size_request(-1, 90)
        page.pack_start(preview, False, False, 0)
        def values():
            result = {}
            for key, control in controls.items():
                c = control.get_rgba()
                result[key] = '#%02x%02x%02x' % tuple(round(v * 255) for v in (c.red, c.green, c.blue))
            return result
        def update_preview(*_):
            c = values()
            preview.set_markup(f"<span background='{c['background']}' foreground='{c['foreground']}'>\n  Terminal text  <span foreground='{c['accent']}'>Accent</span>\n  <span background='{c['selection_background']}' foreground='{c['selection_foreground']}'> Selected text </span>  <span foreground='{c['cursor']}'>▉ Cursor</span>\n</span>")
        for key, label in [('background', 'Terminal background'), ('foreground', 'Terminal text'), ('accent', 'Desktop accent'), ('cursor', 'Terminal cursor'), ('selection_background', 'Selection background'), ('selection_foreground', 'Selected text')]:
            row = Gtk.Box(spacing=12)
            row.pack_start(Gtk.Label(label=label, xalign=0), True, True, 0)
            color = Gdk.RGBA()
            color.parse(colors[key])
            control = Gtk.ColorButton(rgba=color, use_alpha=False, title=label)
            controls[key] = control
            control.connect('color-set', update_preview)
            row.pack_start(control, False, False, 0)
            page.pack_start(row, False, False, 0)
        update_preview()
        reset = {'all': False}
        def defaults(*_):
            original = engine.palette(ROOT / name / 'colors.toml')
            reset['all'] = True
            for key, control in controls.items():
                c = Gdk.RGBA(); c.parse(original[key]); control.set_rgba(c)
            update_preview()
            status.set_text('Original colors previewed. Save and apply to reset personal colors.')
        def save(*_):
            path = ROOT / '.overrides' / (name + '.toml')
            try:
                data = {} if reset['all'] else (tomllib.loads(path.read_text()) if path.exists() else {})
                original = engine.palette(ROOT / name / 'colors.toml')
                for key, value in values().items():
                    if value.lower() == original[key].lower():
                        data.pop(key, None)
                    else:
                        data[key] = value
                if data:
                    custom.atomic(path, ''.join(f'{key} = "{value}"\n' for key, value in data.items()))
                else:
                    path.unlink(missing_ok=True)
                engine.palette(ROOT / name / 'colors.toml', path)
            except (ValueError, OSError) as error:
                status.set_text(str(error)); return
            dialog.destroy()
            self.apply(name)
        def refine_existing(*_):
            images=custom.wallpapers(name)
            selected=custom.selected(name)
            if read_name(ROOT/'current.name')==name and (ROOT/'current/background').is_file():
                selected=(ROOT/'current/background').resolve()
            if selected is None or not selected.is_file():selected=images[0] if images else None
            if selected is None:
                status.set_text('Add a wallpaper first so AI can refine this theme from its image.');return
            palette={k:v for k,v in colors.items() if not k.endswith(('_strip','_rgb'))}
            # Carry unsaved manual edits into the refinement preview.
            palette.update(values())
            dialog.destroy()
            self.creator_preview(str(selected),palette,None,existing_name=name)
        actions = Gtk.Box(spacing=8)
        for label, callback in [('Reset to original', defaults), ('Save and apply', save), ('Refine with AI', refine_existing)]:
            b = Gtk.Button(label=label); b.connect('clicked', callback); actions.pack_start(b, False, False, 0)
        page.pack_start(actions, False, False, 0)
        page.pack_start(Gtk.Label(label='Only Save and apply changes your desktop. Close discards color edits.', wrap=True, xalign=0), False, False, 0)
        color_scroll = Gtk.ScrolledWindow()
        color_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        color_scroll.add(page)
        tabs.append_page(color_scroll, Gtk.Label(label='Terminal & colors'))
        border_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin=12)
        border_preview = Gtk.DrawingArea()
        border_preview.set_size_request(-1, 150)
        border_page.pack_start(border_preview, False, False, 0)
        shape_controls = {}
        shape_values = engine.window_settings(name)
        border_controls = {}
        def border_values():
            result = {}
            for key, control in border_controls.items():
                c = control.get_rgba()
                result[key] = '#%02x%02x%02x' % tuple(round(v * 255) for v in (c.red, c.green, c.blue))
            return result
        def preview_border(*_):
            border_preview.queue_draw()
        def draw_border(widget, cr):
            import cairo
            import math
            width, height = widget.get_allocated_width(), widget.get_allocated_height()
            c = border_values()
            size = shape_controls['border_size'].get_value_as_int()
            radius = shape_controls['rounding'].get_value_as_int()
            def rounded(x, y, w, h, r):
                r = min(r, w / 2, h / 2)
                cr.new_sub_path()
                for cx, cy, start in [(x+w-r,y+r,-90),(x+w-r,y+h-r,0),(x+r,y+h-r,90),(x+r,y+r,180)]:
                    cr.arc(cx,cy,r,math.radians(start),math.radians(start+90))
                cr.close_path()
            gradient = cairo.LinearGradient(0, 0, 0, height)
            for offset, key in [(0,'border_top'),(1,'border_bottom')]:
                rgba=Gdk.RGBA();rgba.parse(c[key]);gradient.add_color_stop_rgb(offset,rgba.red,rgba.green,rgba.blue)
            rounded(8,8,width-16,height-16,radius)
            cr.set_source(gradient);cr.fill()
            rounded(8+size,8+size,width-16-2*size,height-16-2*size,max(0,radius-size))
            rgba=Gdk.RGBA();rgba.parse(colors['background']);Gdk.cairo_set_source_rgba(cr,rgba);cr.fill()
            rgba.parse(colors['foreground']);Gdk.cairo_set_source_rgba(cr,rgba)
            cr.set_font_size(14);cr.move_to(28,height/2);cr.show_text('Focused window preview')
            return False
        border_preview.connect('draw', draw_border)
        for key, label in [('border_top', 'Active border — first color'), ('border_bottom', 'Active border — second color')]:
            row = Gtk.Box(spacing=12)
            row.pack_start(Gtk.Label(label=label, xalign=0), True, True, 0)
            rgba = Gdk.RGBA(); rgba.parse(colors[key])
            control = Gtk.ColorButton(rgba=rgba, use_alpha=False, title=label)
            border_controls[key] = control
            control.connect('color-set', preview_border)
            row.pack_start(control, False, False, 0)
            border_page.pack_start(row, False, False, 0)
        for key, label, maximum in [('border_size', 'Border thickness (px)', 10), ('rounding', 'Corner rounding (px)', 40)]:
            row = Gtk.Box(spacing=12)
            row.pack_start(Gtk.Label(label=label, xalign=0), True, True, 0)
            control = Gtk.SpinButton.new_with_range(0, maximum, 1)
            control.set_value(shape_values[key]);shape_controls[key]=control
            control.connect('value-changed', preview_border)
            row.pack_start(control,False,False,0);border_page.pack_start(row,False,False,0)
        preview_border()
        def reset_border(*_):
            original = engine.palette(ROOT / name / 'colors.toml')
            for key, control in border_controls.items():
                rgba = Gdk.RGBA(); rgba.parse(original[key]); control.set_rgba(rgba)
            preview_border()
            for key, control in shape_controls.items(): control.set_value(engine.WINDOW_DEFAULTS[key])
            status.set_text('Original border colors and default shape previewed. Save to apply.')
        def save_border(*_):
            path = ROOT / '.overrides' / (name + '.toml')
            try:
                # Merge only these two settings; preserve terminal/AI palette edits.
                engine.palette(ROOT / name / 'colors.toml', path)
                data = tomllib.loads(path.read_text()) if path.exists() else {}
                data.update(border_values())
                shape_path = ROOT / '.overrides' / (name + '.window.toml')
                custom.atomic(shape_path, ''.join(f'{key} = {control.get_value_as_int()}\n' for key, control in shape_controls.items()))
                custom.atomic(path, ''.join(f'{key} = "{value}"\n' for key, value in data.items()))
            except (ValueError, OSError) as error:
                status.set_text(str(error)); return
            dialog.destroy()
            self.apply(name)
        border_actions = Gtk.Box(spacing=8)
        for label, callback in [('Reset borders', reset_border), ('Save and apply borders', save_border)]:
            button = Gtk.Button(label=label); button.connect('clicked', callback)
            border_actions.pack_start(button, False, False, 0)
        border_page.pack_start(border_actions, False, False, 0)
        border_page.pack_start(Gtk.Label(label='Choose the same color twice for a solid border.\nZero thickness hides borders; zero rounding gives square corners. Inactive border colors stay unchanged.\nSave applies this theme. Close discards border edits.', xalign=0, wrap=True), False, False, 0)
        tabs.append_page(border_page, Gtk.Label(label='Window borders'))
        nvim_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=12)
        nvim_preview = Gtk.Label(xalign=0)
        nvim_page.pack_start(nvim_preview, False, False, 0)
        nvim_controls = {}
        nvim_values = engine.nvim_colors(name, colors)
        def get_nvim():
            return {k: creator.hexcolor((w.get_rgba().red, w.get_rgba().green, w.get_rgba().blue)) for k,w in nvim_controls.items()}
        def preview_nvim(*_):
            c = get_nvim()
            nvim_preview.set_markup(f"<span font_family='monospace' background='{c['background']}' foreground='{c['text']}'>\n <span foreground='{c['line_number']}'>1</span> <span foreground='{c['comment']}'>-- Editor preview</span>\n <span foreground='{c['line_number']}'>2</span> <span foreground='{c['keyword']}'>local</span> count = <span foreground='{c['number']}'>42</span>\n <span foreground='{c['line_number']}'>3</span> <span foreground='{c['function']}'>print</span>(<span foreground='{c['string']}'>&quot;Hello&quot;</span>) <span foreground='{c['cursor']}'>▉</span>\n <span background='{c['selection']}' foreground='{c['selection_text']}'> Selected text </span> <span foreground='{c['error']}'>Error</span> <span foreground='{c['warning']}'>Warning</span> \n</span>")
        for key, value in nvim_values.items():
            row = Gtk.Box(spacing=12)
            label = key.replace('_', ' ').capitalize()
            row.pack_start(Gtk.Label(label=label, xalign=0), True, True, 0)
            rgba=Gdk.RGBA();rgba.parse(value)
            control=Gtk.ColorButton(rgba=rgba,use_alpha=False,title='Neovim '+label)
            nvim_controls[key]=control;control.connect('color-set',preview_nvim)
            row.pack_start(control,False,False,0);nvim_page.pack_start(row,False,False,0)
        preview_nvim()
        def reset_nvim(*_):
            for key,value in engine.nvim_colors(name,colors,use_override=False).items():
                rgba=Gdk.RGBA();rgba.parse(value);nvim_controls[key].set_rgba(rgba)
            preview_nvim();status.set_text('Theme-derived Neovim colors previewed. Save to apply.')
        def save_nvim(*_):
            path=ROOT/'.overrides'/(name+'.nvim.toml')
            try:
                defaults=engine.nvim_colors(name,colors,use_override=False)
                data={k:v for k,v in get_nvim().items() if v.lower()!=defaults[k].lower()}
                custom.atomic(path,''.join(f'{k} = "{v}"\n' for k,v in data.items()))
            except (ValueError,OSError) as error:
                status.set_text(str(error));return
            dialog.destroy();self.apply(name)
        actions=Gtk.Box(spacing=8)
        for label,callback in [('Reset Neovim colors',reset_nvim),('Save and apply Neovim',save_nvim)]:
            button=Gtk.Button(label=label);button.connect('clicked',callback);actions.pack_start(button,False,False,0)
        nvim_page.pack_start(actions,False,False,0)
        nvim_page.pack_start(Gtk.Label(label='Neovim follows this palette when opened or refocused. Save applies this theme.\nPreview is illustrative; syntax groups depend on the language. Close discards edits.',wrap=True,xalign=0),False,False,0)
        nvim_scroll=Gtk.ScrolledWindow();nvim_scroll.set_policy(Gtk.PolicyType.NEVER,Gtk.PolicyType.AUTOMATIC);nvim_scroll.add(nvim_page)
        tabs.append_page(nvim_scroll,Gtk.Label(label='Neovim'))
        prompt_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=12)
        prompt_preview = Gtk.Label(xalign=0)
        prompt_page.pack_start(prompt_preview, False, False, 0)
        prompt_values = engine.prompt_colors(name, colors)
        prompt_controls = {}
        def get_prompt():
            result = {}
            for key, control in prompt_controls.items():
                c=control.get_rgba();result[key]=creator.hexcolor((c.red,c.green,c.blue))
            return result
        def preview_prompt(*_):
            c=get_prompt()
            prompt_preview.set_markup(f"<span background='{colors['background']}'>\n <span foreground='{c['prompt_user']}'>adept</span><span foreground='{c['prompt_at']}'>@</span><span foreground='{c['prompt_host']}'>syna</span> : <span foreground='{c['prompt_directory']}'>~/projects</span>\n <span foreground='{c['prompt_success']}'>❯ Success</span>   <span foreground='{c['prompt_error']}'>❯ Error</span> \n</span>")
        for key,label in [('prompt_user','Username'),('prompt_at','@ separator'),('prompt_host','Hostname'),('prompt_directory','Directory'),('prompt_success','Success prompt symbol'),('prompt_error','Error prompt symbol / root username')]:
            row=Gtk.Box(spacing=10);row.pack_start(Gtk.Label(label=label,xalign=0),True,True,0)
            rgba=Gdk.RGBA();rgba.parse(prompt_values[key]);control=Gtk.ColorButton(rgba=rgba,use_alpha=False,title=label)
            prompt_controls[key]=control;control.connect('color-set',preview_prompt);row.pack_start(control,False,False,0)
            prompt_page.pack_start(row,False,False,0)
        preview_prompt()
        def reset_prompt(*_):
            defaults=engine.prompt_colors(name,colors,use_override=False)
            for key,control in prompt_controls.items():
                rgba=Gdk.RGBA();rgba.parse(defaults[key]);control.set_rgba(rgba)
            preview_prompt();status.set_text('Default prompt colors previewed. Save to apply.')
        def save_prompt(*_):
            defaults=engine.prompt_colors(name,colors,use_override=False)
            settings={k:v for k,v in get_prompt().items() if v.lower()!=defaults[k].lower()}
            path=ROOT/'.overrides'/(name+'.prompt.toml')
            try:
                if settings:custom.atomic(path,''.join(f'{k} = "{v}"\n' for k,v in settings.items()))
                else:path.unlink(missing_ok=True)
                engine.prompt_colors(name,colors)
            except (OSError,ValueError) as error:status.set_text(str(error));return
            dialog.destroy();self.apply(name)
        prompt_actions=Gtk.Box(spacing=8)
        for label,callback in [('Reset prompt colors',reset_prompt),('Save and apply prompt',save_prompt)]:
            button=Gtk.Button(label=label);button.connect('clicked',callback);prompt_actions.pack_start(button,False,False,0)
        prompt_page.pack_start(prompt_actions,False,False,0)
        prompt_page.pack_start(Gtk.Label(label='Preview labels only: this changes colors, not your username or hostname.\nNew colors appear when the next shell prompt is drawn. Git modules remain hidden.',xalign=0,wrap=True),False,False,0)
        tabs.append_page(prompt_page,Gtk.Label(label='Shell prompt'))
        icon_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=12)
        icon_page.pack_start(Gtk.Label(label='Folder and app icons in GTK apps (Files, dialogs) while this theme is active.', xalign=0, wrap=True), False, False, 0)
        icon_default = engine.theme_icons(name, use_override=False) or engine.DEFAULT_ICONS
        icon_current = engine.theme_icons(name) or engine.DEFAULT_ICONS
        icon_choice = Gtk.ComboBoxText()
        icon_names = engine.icon_themes()
        if icon_current not in icon_names: icon_names.append(icon_current)
        for icon_name in icon_names:
            icon_choice.append(icon_name, icon_name + ('  (theme default)' if icon_name == icon_default else ''))
        icon_choice.set_active_id(icon_current)
        icon_page.pack_start(icon_choice, False, False, 0)
        def reset_icons(*_):
            icon_choice.set_active_id(icon_default); status.set_text('Theme default icons selected. Save to apply.')
        def save_icons(*_):
            chosen = icon_choice.get_active_id()
            path = ROOT / '.overrides' / (name + '.icons')
            try:
                if chosen and chosen != icon_default: custom.atomic(path, chosen + '\n')
                else: path.unlink(missing_ok=True)
                engine.theme_icons(name)
            except (OSError, ValueError) as error: status.set_text(str(error)); return
            dialog.destroy(); self.apply(name)
        icon_actions = Gtk.Box(spacing=8)
        for label, callback in [('Reset icons', reset_icons), ('Save and apply icons', save_icons)]:
            button = Gtk.Button(label=label); button.connect('clicked', callback); icon_actions.pack_start(button, False, False, 0)
        icon_page.pack_start(icon_actions, False, False, 0)
        icon_page.pack_start(Gtk.Label(label='Accent colour for GTK apps follows this theme\'s accent (Terminal & colors tab). Apps pick up changes after a restart.', xalign=0, wrap=True), False, False, 0)
        tabs.append_page(icon_page, Gtk.Label(label='Icons'))
        wallpage = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10, margin=12)
        wallpage.pack_start(Gtk.Label(label='Import copies images into this theme. Remove archives them with Undo.', wrap=True, xalign=0), False, False, 0)
        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        rows = Gtk.ListBox(selection_mode=Gtk.SelectionMode.SINGLE)
        rows.get_style_context().add_class('wallpaper-list')
        def selection_changed(widget, selected):
            for row in widget.get_children():
                row.check.set_text('✓ Selected' if row == selected else '')
            if selected is not None:
                status.set_text('Selected: ' + selected.path.name + '. Choose Use wallpaper to apply it.')
        rows.connect('row-selected', selection_changed)
        scroll.add(rows)
        wallpage.pack_start(scroll, True, True, 0)
        removed = custom.removed_archives(name)
        undo = Gtk.Button(label='Undo removal')
        def refresh_walls():
            for row in rows.get_children(): rows.remove(row)
            for path in custom.wallpapers(name):
                row = Gtk.ListBoxRow(); row.path = path
                line = Gtk.Box(spacing=10, margin=5)
                image = Gtk.Image()
                try: image.set_from_pixbuf(GdkPixbuf.Pixbuf.new_from_file_at_scale(str(path), 130, 75, True))
                except GLib.Error: image.set_from_icon_name('image-missing', Gtk.IconSize.DIALOG)
                line.pack_start(image, False, False, 0)
                label = Gtk.Label(label=path.name, xalign=0, wrap=True)
                label.set_max_width_chars(36)
                line.pack_start(label, True, True, 0)
                row.check = Gtk.Label(label='', xalign=1)
                row.check.set_width_chars(10)
                line.pack_start(row.check, False, False, 0)
                row.add(line); rows.add(row)
            rows.show_all()
            undo.set_sensitive(bool(removed))
        def import_images(*_):
            chooser = Gtk.FileChooserDialog(title='Import wallpapers', transient_for=dialog, action=Gtk.FileChooserAction.OPEN)
            chooser.add_buttons('Cancel', Gtk.ResponseType.CANCEL, 'Import', Gtk.ResponseType.OK)
            chooser.set_select_multiple(True)
            filt = Gtk.FileFilter(); filt.set_name('Images')
            for pattern in ['*.png', '*.jpg', '*.jpeg', '*.webp', '*.avif', '*.PNG', '*.JPG', '*.JPEG']: filt.add_pattern(pattern)
            chooser.add_filter(filt)
            if chooser.run() == Gtk.ResponseType.OK:
                count = 0
                try:
                    for filename in chooser.get_filenames():
                        GdkPixbuf.Pixbuf.new_from_file_at_scale(filename, 32, 32, True)
                        custom.import_wallpaper(name, Path(filename)); count += 1
                    status.set_text(f'Imported {count} wallpaper(s). Select one and choose Use wallpaper.')
                except (OSError, ValueError, GLib.Error) as error: status.set_text(f'Imported {count}. {error}')
                refresh_walls(); self.refresh()
            chooser.destroy()
        def use_wallpaper(*_):
            row = rows.get_selected_row()
            if row is None: status.set_text('Select a wallpaper first.'); return
            try: custom.select(name, row.path)
            except (OSError, ValueError) as error: status.set_text(str(error)); return
            dialog.destroy(); self.apply(name)
        def remove_wallpaper(*_):
            row = rows.get_selected_row()
            if row is None: status.set_text('Select a wallpaper first.'); return
            try:
                removed.append(custom.remove(name, row.path))
                refresh_walls(); self.refresh()
                status.set_text('Wallpaper removed from this theme. Undo restores the file.')
                if read_name(ROOT / 'current.name') == name:
                    self.apply(name)
            except (OSError, ValueError) as error: status.set_text(str(error))
        def restore_wallpaper(*_):
            try:
                custom.undo(removed[-1]); removed.pop(); refresh_walls(); self.refresh()
                status.set_text('Wallpaper restored. Select Use wallpaper to display it.')
            except (OSError, ValueError) as error: status.set_text(str(error))
        buttons = Gtk.Box(spacing=5)
        for label, callback in [('Import…', import_images), ('Use wallpaper', use_wallpaper), ('Remove', remove_wallpaper)]:
            b=Gtk.Button(label=label); b.connect('clicked', callback); buttons.pack_start(b, False, False, 0)
        undo.connect('clicked', restore_wallpaper); buttons.pack_start(undo, False, False, 0)
        wallpage.pack_start(buttons, False, False, 0)
        tabs.append_page(wallpage, Gtk.Label(label='Wallpapers'))
        refresh_walls()
        dialog.connect('response', lambda *_: dialog.destroy())
        dialog.show_all()

    def apply(self, name):
        if self.busy:
            return
        self.busy = True
        if self.editor is not None: self.editor.set_sensitive(False)
        self.cards.set_sensitive(False)
        self.restore.set_sensitive(False)
        self.status.set_text('Restoring previous theme…' if name == '--previous' else 'Applying ' + title(name) + '…')
        def worker():
            try:
                result = subprocess.run([str(SCRIPTS / 'syna-theme-set'), name], capture_output=True, text=True, timeout=300)
                message = (result.stdout if result.returncode == 0 else result.stderr).strip()
                if not message:
                    message = 'Theme applied.' if result.returncode == 0 else 'Theme could not be applied.'
            except (OSError, subprocess.TimeoutExpired) as error:
                message = str(error)
            GLib.idle_add(self.finished, message)
        threading.Thread(target=worker, daemon=True).start()

    def finished(self, message):
        self.busy = False
        if self.editor is not None: self.editor.set_sensitive(True)
        self.cards.set_sensitive(True)
        self.refresh(message)
        return False


if __name__ == '__main__':
    raise SystemExit(Picker().run(sys.argv))
