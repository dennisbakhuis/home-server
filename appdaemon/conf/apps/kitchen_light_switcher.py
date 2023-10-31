#####################################################################
# Kitchen light switches                                            #
##################################################
# Controlls lights in kitchen with two switches
#
# Switch 1: 
#   - if light off: turn on
#   - if light on: toggle automatic light
# Switch 2:
#   - switch low_state mode (relax mode) including off                   
#
# EXAMPLE entry for apps.yaml:                 
#                                              
# multi_switch_kitchen:
#   module: kitchen_light_switcher
#   class: KitchenLightSwitcher
#   switch_left: switch.shelly_keuken_links
#   switch_right: switch.shelly_keuken_rechts
#   motion_sensors:
#     - binary_sensor.pir_b_keuken
#   illuminance_sensor: sensor.estimated_illuminance
#   light_group: light.keuken
#   auto_light_toggle: input_boolean.automatic_light_kitchen
#   relax_input_select: input_select.kitchen_lower_dimlevel
#   work_input_select: input_select.kitchen_higher_dimlevel
#   relax_scenes:
#     - scene.keuken_relax_off
#     - scene.keuken_relax_two
#   work_scenes:
#     - scene.keuken_work_yellow
#     - scene.keuken_work_white
#   light_duration: 120
#   solar_power_sensor_threshold: 1
#   log_level: DEBUG
##################################################
# Author: Dennis Bakhuis
# Date: 2022 January 01
##################################################
import hassapi as hass

class KitchenLightSwitcher(hass.Hass):
    VERSION = '0.2.0'

    def initialize(self):
        self.set_namespace('hass')

        # Physical sensors
        self.switch_left = self.args['switch_left']
        self.switch_right = self.args['switch_right']
        self.motion_sensors = self.args['motion_sensors']
        self.solar_power_sensor = self.args['solar_power_sensor']

        # Physical light
        self.light_group = self.args['light_group']

        # UI sensors
        self.auto_light_toggle = self.args['auto_light_toggle']
        self.work_input_select = self.args['work_input_select']
        self.relax_input_select = self.args['relax_input_select']

        # Scenes and default values
        self.work_scenes = self.args['work_scenes']
        self.relax_scenes = self.args['relax_scenes']
        self.light_duration = int(self.args.get('light_duration', 120))
        self.solar_power_sensor_threshold = int(self.args.get('solar_power_sensor_threshold', 500))

        # Set light-timer to None
        self.lights_timer = None

        # Set up listeners
        self.listen_state(
            self.switch_left_callback,
            self.switch_left,
        )
        self.listen_state(
            self.switch_right_callback,
            self.switch_right,
        )
        for motion_sensor in self.motion_sensors:
            self.listen_state(
                self.motion_callback,
                motion_sensor,
            )
        
        # Set up listeners for UI elements
        self.listen_state(
            self.ui_toggle_automatic_light,
            self.auto_light_toggle,
        )
        self.listen_state(
            self.ui_low_dimlevel_change,
            self.relax_input_select,
        )
        self.listen_state(
            self.ui_high_dimlevel_change,
            self.work_input_select,
        )

        self.log(
            f"Kitchen light switches {self.VERSION} online",
            level='INFO',
        )


    def _check_state(self, entity):
        """
        Check if entity is on.
        """
        light_state = self.get_state(entity)
        if light_state == "on":
            return True
        return False


    def light_group_on(self):
        """
        Check if light is on
        """
        return self._check_state(self.light_group)

    
    def automatic_light_on(self):
        """
        Check if automatic light feature is on.
        """
        return self._check_state(self.auto_light_toggle)

    
    def low_power(self):
        """
        Check if power_production is below threshold
        """
        power = float(self.get_state(self.solar_power_sensor))
        self.log(
            f"Power is : {power}", 
            level="DEBUG",
        )
        if power <= self.solar_power_sensor_threshold:
            return True
        return False


    def set_scene(self, input_select, scenes):
        """
        Set new scene
        """
        scene_key = self.get_state(input_select)
        # self.log(
        #     f"Setting new scene: {scene_key}", 
        #     level="DEBUG",
        # )
        scene = scenes[scene_key]
        self.turn_on(scene)


    def switch_low_dimlevel(self, *args, **kwargs):
        """
        Called when timer is done.
        """
        self.lights_timer = None
        if self.automatic_light_on():
            self.set_scene(self.relax_input_select, self.relax_scenes)
        else:
            self.log(
                f"Auto light is turned off, do nothing",
                level="DEBUG",
            )


    def switch_left_callback(self, entity, attribute, old, new, kwargs):
        """
        Callback when left switch is pressed
        """
        self.log(
            f"Left switch pressed, state {new}",
            level="DEBUG",
        )
        if self.light_group_on():
            self.log('Light group on!', level="DEBUG")
            self.toggle(self.auto_light_toggle)
        else:
            self.log('Light group on!', level="DEBUG")
            self.set_scene(self.work_input_select, self.work_scenes)

    

    def switch_right_callback(self, entity, attribute, old, new, kwargs):
        self.log(
            f"Right switch pressed, state {new}",
            level="DEBUG",
        )
        self.call_service(
            "input_select/select_next", 
            entity_id=self.relax_input_select, 
        )
        self.set_scene(self.relax_input_select, self.relax_scenes)


    def cancel_lights_timer(self):
        if self.lights_timer is not None:
            self.cancel_timer(self.lights_timer)
            self.lights_timer = None


    def set_lights_timer(self):
        self.lights_timer = self.run_in(
            self.switch_low_dimlevel,
            self.light_duration,
        )


    def motion_callback(self, entity, attribute, old, new, kwargs):
        """
        Callback when motion is detected from one of the motion sensors
        """
        self.log(f"Motion detected, state: {new}", level="DEBUG",)
        if self.automatic_light_on():
            self.log("Automatic light is on.", level="DEBUG",)
            if new == 'on':
                if self.low_power():
                    self.log("It is dark enough to turn on lights.", level="DEBUG",)
                    self.cancel_lights_timer()
                    self.set_scene(self.work_input_select, self.work_scenes)
                else:
                    self.log("It not dark enough to turn on lights", level="DEBUG",)
            else:
                self.log("Setting up light off procedure", level="DEBUG",)
                self.cancel_lights_timer()
                self.set_lights_timer()
        else:
            self.log("Automatic light is off.", level="DEBUG",)
    

    def ui_toggle_automatic_light(self, entity, attribute, old, new, kwargs):
        if new == 'on':
            self.set_lights_timer()
        else:
            self.cancel_lights_timer()


    def ui_low_dimlevel_change(self, entity, attribute, old, new, kwargs):
        self.set_scene(self.relax_input_select, self.relax_scenes)


    def ui_high_dimlevel_change(self, entity, attribute, old, new, kwargs):
        self.set_scene(self.work_input_select, self.work_scenes)