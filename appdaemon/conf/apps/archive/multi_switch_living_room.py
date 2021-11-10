import adbase as ad

class Multi_Switch_Living_Room(ad.ADBase):
    """
    Multi Switch for Living room. Only listens to mqtt for these switches
    and toggles the lights accordingly.

    Currently, the long-pushes are not used.
    """

    TOPIC_RIGHT_SWITCH = "shellies/shellyswitch25-C45D1E/input/0"
    TOPIC_LEFT_SWITCH = "shellies/shellyswitch25-C45D1E/input/1"
    LIGHTS_LIVING_ROOM = [
        "light.woonkamer",
    ]
    LIGHTS_DINER = [
        "light.eettafel",
    ]
    LONG_PUSH_TIME = 0.900


    def initialize(self):
        self.hass = self.get_plugin_api("HASS")
        self.mqtt = self.get_plugin_api("MQTT")
        self.adbase = self.get_ad_api()

        self.time_zero = None

        self.adbase.log("Living room switch online.")

        # Listen to right switch
        self.mqtt.listen_event(
            self.push_translator_living_room, 
            "MQTT_MESSAGE", 
            topic=self.TOPIC_RIGHT_SWITCH,
        )
        # Listen to left switch
        self.mqtt.listen_event(
            self.push_translator_diner, 
            "MQTT_MESSAGE", 
            topic=self.TOPIC_LEFT_SWITCH,
        )


    def push_translator_living_room(self, event_name, data, kwargs):
        topic = data['topic']
        payload = data['payload']
        if payload == "1":
            self.time_zero = self.adbase.get_now_ts()
        elif payload == "0" and self.time_zero is not None:
            dt = self.adbase.get_now_ts() - self.time_zero
            self.time_zero = None
            if dt < self.LONG_PUSH_TIME:
                self.short_push_action_living_room()
            else:
                self.long_push_action_living_room()


    def short_push_action_living_room(self):
        for light_entity in self.LIGHTS_LIVING_ROOM:
            self.hass.toggle(light_entity)


    def long_push_action_living_room(self):
        pass


    def push_translator_diner(self, event_name, data, kwargs):
        topic = data['topic']
        payload = data['payload']
        if payload == "1":
            self.time_zero = self.adbase.get_now_ts()
        elif payload == "0" and self.time_zero is not None:
            dt = self.adbase.get_now_ts() - self.time_zero
            self.time_zero = None
            if dt < self.LONG_PUSH_TIME:
                self.short_push_action_diner()
            else:
                self.long_push_action_diner()


    def short_push_action_diner(self):
        for light_entity in self.LIGHTS_DINER:
            self.hass.toggle(light_entity)


    def long_push_action_diner(self):
        pass
