#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#   Plug-in to create frequency separation layers in GIMP 3.
#
#   Copyright (C) 2025 Chuck Henrich
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details: <https://www.gnu.org/licenses/>.

import sys

import gi

gi.require_version("Gimp", "3.0")
from gi.repository import Gimp

gi.require_version("GimpUi", "3.0")
gi.require_version("Gegl", "0.4")
gi.require_version("Gtk", "3.0")    
from gi.repository import Gtk, GLib, Gegl


# Initialize GEGL before any operations
Gegl.init(None)


class FrequencySeparationGroupPlugin(Gimp.PlugIn):
    def do_query_procedures(self):
        return ["frequency-separation-group-v3"]

    def do_set_i18n(self, name):
        return False

    def do_create_procedure(self, name):
        procedure = Gimp.ImageProcedure.new(
            self, name, Gimp.PDBProcType.PLUGIN, self.run, None
        )

        procedure.set_image_types("*")

        procedure.set_menu_label("Frequency separation group")
        procedure.add_menu_path("<Image>/Layer/")

        procedure.set_documentation(
            "Create a frequency separation group layer",
            "This plugin creates a frequency separation group layer for advanced editing.",
            name,
        )
        procedure.set_attribution("Chuck Henrich", "Chuck Henrich", "2025")

        return procedure

    def run(self, procedure, run_mode, image, drawables, config, run_data):
        try:
            # Start a grouped undo step
            image.undo_group_start()

            # Create frequency separation group to contain texture and colour/tone layers
            frequency_separation_group = Gimp.GroupLayer.new(
                image, "Frequency separation"
            )
            image.insert_layer(frequency_separation_group, None, -1)

            # Save a temporary copy of the working base layer to use when building texture layer
            temp_texture_layer = Gimp.Layer.new_from_visible(
                image, image, "temp texture layer"
            )

            # Create the blur layer and display dialog to appply the blur

            colour_tone_layer = Gimp.Layer.new_from_visible(
                image, image, "Colour/tone layer"
            )
            image.insert_layer(colour_tone_layer, frequency_separation_group, 1)

            # self.initialize_blur_filter(colour_tone_layer)

            # Ensure the blur dialog is created with a valid parent window
            dialog = GaussianBlurDialog(None, self, image, colour_tone_layer)
            response = Gtk.Dialog.run(dialog)
            dialog.destroy()  # Ensure the dialog is properly freed

            if response == Gtk.ResponseType.CANCEL:
                # Hide the blur dialog before showing the warning
                dialog.hide()
                Gimp.Image.remove_layer(image, frequency_separation_group)

                # Show a warning dialog instead of Gimp.message()
                warning_dialog = Gtk.MessageDialog(
                    transient_for=None,
                    flags=Gtk.DialogFlags.MODAL,
                    message_type=Gtk.MessageType.WARNING,  # ⚠️ Yellow warning triangle
                    buttons=Gtk.ButtonsType.OK,
                    text="Process canceled",
                )
                warning_dialog.set_position(
                    Gtk.WindowPosition.CENTER
                )  # Center the dialog
                warning_dialog.format_secondary_text(
                    "The frequency separation process was canceled by the user."
                )
                warning_dialog.run()
                warning_dialog.destroy()

                dialog.destroy()  # Fully remove the blur dialog
                return procedure.new_return_values(
                    Gimp.PDBStatusType.CANCEL, GLib.Error()
                )

            # Store blur radius before destroying the dialog
            blur_radius = dialog.selected_blur_radius
            dialog.destroy()  # Close blur dialog (if not already destroyed)

            # Apply the Gaussian blur to the colour tone layer
            self.apply_gaussian_blur_to_layer(image, colour_tone_layer, blur_radius)

            # Create a temp layer as a copy of the base layer and a temp layer as a
            # copy of the colour/tone layer, then place them in a temp working group
            temp_working_group = Gimp.GroupLayer.new(image, "temp working group")
            Gimp.Image.insert_layer(
                image, temp_working_group, frequency_separation_group, 0
            )

            temp_blur_layer = Gimp.Layer.copy(colour_tone_layer)
            Gimp.Image.insert_layer(image, temp_blur_layer, temp_working_group, 0)

            # Insert the temp_texture_layer into the temp_working_group)
            Gimp.Image.insert_layer(image, temp_texture_layer, temp_working_group, 0)

            # Set the temp_texture_layer mode to grain extract
            temp_texture_layer.set_mode(46)  # 46 = GIMP_LAYER_MODE_GRAIN_EXTRACT

            # Merge the temp group and rename it
            texture_layer = Gimp.GroupLayer.merge(temp_working_group)
            texture_layer.set_name("Texture layer")

            # Set the texture layer mode to grain extract (necessary step)
            texture_layer.set_mode(46)  # 46 = GIMP_LAYER_MODE_GRAIN_EXTRACT

            # Desaturate the texture layer so it only works on luminance
            # Gimp.Drawable.desaturate(texture_layer, 0)

            message_dialog = Gtk.MessageDialog(
                transient_for=None,
                flags=Gtk.DialogFlags.MODAL,
                message_type=Gtk.MessageType.INFO,
                buttons=Gtk.ButtonsType.OK,
                text="Next steps",
            )
            message_dialog.set_position(Gtk.WindowPosition.CENTER)  # Center the dialog
            message_dialog.format_secondary_text(
                "A 'Frequency separation' group has been added to your image.\n\n"
                "The layers inside the group allow you to work separately on texture and colour/tone.\n\n"
                "Your specified Gaussian blur has been applied to the colour/tone layer. "
                "The blur on that layer should remove fine details, leaving just colour and tone. \n\n"
                "If the blur you applied is too much or too little, delete the frequency separation group "
                "that has been added to your image, and run the process again. "
                "Use the colour/tone layer to adjust colour and tone with a brush or any other tool that works for you.\n\n"
                "Use the texture layer to fix blemishes, texture issue, etc. Work on that layer with the clone or healing tools."
            )
            message_dialog.run()
            message_dialog.destroy()

        except Exception as e:
            Gimp.message(f"❌ Error:\n\n{e}")

        finally:
            # Ensure undo group is properly closed
            image.undo_group_end()
            image.undo_push_group_end()  # 🔹 Explicitly push the group to the undo history

        return procedure.new_return_values(Gimp.PDBStatusType.SUCCESS, GLib.Error())

    def apply_gaussian_blur_to_layer(self, image, layer, blur_radius):
        try:
            # Step 1: Create a DrawableFilter
            filter = Gimp.DrawableFilter.new(
                layer, "gegl:gaussian-blur", "Gaussian Blur Filter"
            )
            filter.set_blend_mode(Gimp.LayerMode.REPLACE)
            filter.set_opacity(1.0)

            # Step 2: Get filter configuration
            config = filter.get_config()

            # Step 3: Set blur radius (std-dev-x and std-dev-y)
            config.set_property("std-dev-x", blur_radius)
            config.set_property("std-dev-y", blur_radius)

            # Step 4: Apply the filter
            filter.update()

            # Step 5: Append the filter to the drawable
            layer.append_filter(filter)

        except Exception as e:
            Gimp.message(f"❌ Error applying Gaussian Blur:\n\n{e}")


class GaussianBlurDialog(Gtk.Dialog):
    def __init__(self, parent, plugin, image, layer):
        Gtk.Dialog.__init__(
            self, title="Gaussian blur", parent=parent, flags=Gtk.DialogFlags.MODAL
        )

        # Clean up memory on dialog destroy
        self.connect("destroy", self.on_dialog_destroy)

        self.plugin = plugin
        self.image = image
        self.layer = layer
        self.blur_timer_id = None

        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_default_size(400, 200)

        box = self.get_content_area()
        box.set_spacing(10)
        box.set_margin_top(20)
        box.set_margin_bottom(20)
        box.set_margin_start(20)
        box.set_margin_end(20)

        label_spinner_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.add(label_spinner_box)

        label = Gtk.Label(label="Select a Gaussian blur radius:")
        label.set_xalign(0)
        label_spinner_box.pack_start(label, False, False, 0)

        adjustment = Gtk.Adjustment(
            value=5.0, lower=0.1, upper=999.9, step_increment=0.1, page_increment=1.0
        )
        self.spinner = Gtk.SpinButton(adjustment=adjustment, climb_rate=0.1, digits=1)
        self.spinner.set_value(5.0)
        self.spinner.set_width_chars(6)
        label_spinner_box.pack_start(self.spinner, False, False, 0)

        # 🔹 Store the selected blur radius
        self.selected_blur_radius = 5.0  # Default value

        # Connect the spinner value-changed signal
        self.spinner.connect("value-changed", self.on_spinner_value_changed)

        instruction_label = Gtk.Label(
            label="Choose a Gaussian blur that blurs texture details, leaving just colour and tone. "
                  "Your image will update to show a preview of the blur when you press the + and - buttons, "
                  "or when you type a value and press tab."
        )
        instruction_label.set_xalign(0.0)
        instruction_label.set_line_wrap(True)
        box.add(instruction_label)

        self.add_buttons(
            Gtk.STOCK_OK, Gtk.ResponseType.OK, Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL
        )
        self.show_all()

        # Initialize the blur filter and apply the default value
        self.initialize_blur_filter()
        self.update_blur(self.spinner.get_value())  # Apply initial blur

    def initialize_blur_filter(self):
        # Initializes the Gaussian blur filter on the colour/tone layer.
        try:
            self.blur_filter = Gimp.DrawableFilter.new(
                self.layer, "gegl:gaussian-blur", "Gaussian Blur Filter"
            )
            self.blur_filter.set_blend_mode(Gimp.LayerMode.REPLACE)
            self.blur_filter.set_opacity(1.0)
            self.config = self.blur_filter.get_config()

            # Apply default blur value
            default_blur_radius = self.spinner.get_value()
            self.config.set_property("std-dev-x", default_blur_radius)
            self.config.set_property("std-dev-y", default_blur_radius)
            self.blur_filter.update()

            # Append filter to the drawable
            self.layer.append_filter(self.blur_filter)

        except Exception as e:
            Gimp.message(f"❌ Error initializing Gaussian Blur Filter:\n\n{e}")

    def update_blur(self, blur_radius):
        # Updates the blur filter dynamically when the user changes the value.
        try:
            if hasattr(self, "blur_filter") and self.blur_filter:
                self.config.set_property("std-dev-x", blur_radius)
                self.config.set_property("std-dev-y", blur_radius)

                # 🔹 Ensure the filter update is processed
                self.blur_filter.update()
                # 🔹 Force GIMP to redraw the image
                Gimp.displays_flush()

            else:
                Gimp.message("❌ Error: \n\nBlur filter not initialized.")

        except Exception as e:
            Gimp.message(f"❌ Error in update_blur:\n\n{e}")

    def on_spinner_value_changed(self, spinner):
        # Trigger the blur update when the spinner value changes, but debounce updates.
        blur_radius = spinner.get_value()
        self.selected_blur_radius = blur_radius  # 🔹 Store the selected blur radius

        # Cancel any existing pending update
        if self.blur_timer_id:
            GLib.source_remove(self.blur_timer_id)

        # Set a new timer (e.g., 100ms delay)
        self.blur_timer_id = GLib.timeout_add(100, self._delayed_update, blur_radius)

    def _delayed_update(self, blur_radius):
        # Executes the update_blur function after a short delay.
        self.update_blur(blur_radius)
        self.blur_timer_id = None  # Reset timer ID
        return False  # Ensures the timeout runs only once

    def on_dialog_destroy(self, widget):
        if self.blur_timer_id:
            GLib.source_remove(self.blur_timer_id)
            self.blur_timer_id = None


Gimp.main(FrequencySeparationGroupPlugin.__gtype__, sys.argv)
