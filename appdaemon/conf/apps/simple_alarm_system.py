#####################################################################
# Simple Alarm System v1                                            #
#####################################################################
# As the name says, a simple alarm system
# 
# EXAMPLE entry for apps.yaml:
#
# simple_alarm_system:
#   module: simple_alarm_system
#   class: SimpleAlarmSystem
#   alarm_panel: alarm_control_panel.bakhuis_alarm
#   motion_sensors:
#     - binary_sensor.pir_b_keuken
#   motion_sensors_friendly_names:
#     - keuken
#   motion_sensors_ignore_home: []
#   motion_sensors_delayed: []
#   delay_time: 30
#   silent_alarm_switch: input_boolean.alarm_silent_mode
#   sirens:
#     - switch.plug_5_alarm_siren_2_serre
#     - switch.plug_6_alarm_siren_1_modem
#     - switch.plug_7_alarm_siren_3
#   notify_services: 
#     - everybody
#####################################################################
# Author: Dennis Bakhuis                                            #
# Date: 2022 March 14                                               #
#####################################################################
import hassapi as hass

class SimpleAlarmSystem(hass.Hass):
    VERSION = '0.0.1'

    def initialize(self):
        self.set_namespace('hass')

        # Settings
        self.alarm_panel = self.args['alarm_panel']
        self.alarm_name = self.friendly_name(self.alarm_panel)
        self.motion_sensors = self.args['motion_sensors']
        self.motion_sensors_names = self.args['motion_sensors_friendly_names']
        self.motion_sensors_ignore_home = self.args['motion_sensors_ignore_home']
        self.motion_sensors_delayed = self.args['motion_sensors_delayed']
        self.notify_services = self.args['notify_services']
        self.delay_time = self.args['delay_time']
        self.delay_timer = None
        self.sirens = self.args['sirens']
        self.silent_alarm = self.args['silent_alarm_switch']

        # Callbacks
        self.listen_state(
            self.alarm_state_watcher,
            self.alarm_panel,
        )

        for sensor in self.motion_sensors:
            self.listen_state(
                self.motion_detected,
                sensor,
            )

        # Ready
        self.log(f"Simple Alarm System v{self.VERSION} online")


    def alarm_state_watcher(self, entity, attribute, old, new, kwargs):
        if new == 'armed_home':
            self.turn_off_sirens()
            self.notify_notifiers('Alarm is armed in home mode.')
        elif new == 'armed_away':
            self.turn_off_sirens()
            self.notify_notifiers('Alarm is armed in away mode.')
        elif new == 'disarmed':
            self.cancel_delayed_alarm()
            self.turn_off_sirens()
            self.notify_notifiers('Alarm is disarmed.')
        elif new == 'triggered':
            self.turn_on_sirens()
            self.notify_notifiers('Alarm is triggered!')


    def notify_notifiers(self, message: str):
        for notify_service in self.notify_services:
            self.notify(
                message,
                name=notify_service,
            )
    

    def get_alarm_state(self) -> str:
        state = self.get_state(self.alarm_panel)
        return state

    
    def trigger_alarm(self, entity=None):
        if entity is not None:
            pir_name = self.get_friendly_name(entity)
            self.notify_notifiers(
                f"Alarm triggered by {pir_name}",
            )
        self.call_service(
            "alarm_control_panel/alarm_trigger",
            entity_id=self.alarm_panel,
        )


    def trigger_alarm_delayed(self, entity=None):
        if self.delay_timer is not None:
            if entity is not None:
                pir_name = self.get_friendly_name(entity)
                self.notify_notifiers(
                    f"Alarm triggered by {pir_name}",
                )
            self.delay_timer = self.run_in(
                self.trigger_alarm,
                self.delay_time,
            )

    
    def cancel_delayed_alarm(self):
        if self.delay_timer is not None:
            self.cancel_timer(self.delay_timer)
            self.delay_timer = None


    def get_friendly_name(self, entity):
        try:
            index = self.motion_sensors.index(entity)
            return self.motion_sensors_friendly_names[index]
        except:
            return entity
    

    def motion_detected(self, entity, attribute, old, new, kwargs):
        if new == 'on':  # motion triggered
            alarm_state = self.get_alarm_state()

            if alarm_state == 'disarmed': 
                return
            
            if alarm_state == 'armed_home':
                if entity in self.motion_sensors_ignore_home:
                    return
                self.trigger_alarm(entity=entity)

            if alarm_state == 'armed_away':
                if entity in self.motion_sensors_delayed:
                    self.trigger_alarm_delayed(entity=entity)
                else:
                    self.trigger_alarm(entity=entity)

            self.log(f"***> Entity: {entity}")
    

    def turn_on_sirens(self):
        silent_alarm = self.get_state(self.silent_alarm)
        if silent_alarm == 'off':
            for siren in self.sirens:
                self.call_service(
                    "switch/turn_on", 
                    entity_id=siren, 
                )
        else:
            self.notify_notifiers('Silent mode is on!')


    def turn_off_sirens(self):
        for siren in self.sirens:
            self.call_service(
                "switch/turn_off", 
                entity_id=siren, 
            )
