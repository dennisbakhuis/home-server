import adbase as ad

class Multi_Switch_Kitchen(ad.ADBase):

    TOPIC_LEFT = "shellies/shelly1-C4950C/input/0"
    TOPIC_RIGHT = "shellies/shelly1-C4E76B/input/0"
    HIGH_INPUT_SELECT = "input_select.kitchen_higher_dimlevel"
    LOW_INPUT_SELECT = "input_select.kitchen_lower_dimlevel"
    HIGH_LEVELS = (
        ('Wit', 'scene.keuken_work_white'),
        ('Geel', 'scene.keuken_work_yellow'),
    )
    LOW_LEVELS = (
        ('Uit', 'scene.keuken_relax_off'),
        ('Twee', 'scene.keuken_relax_two'),
        ('Alles', 'scene.keuken_relax_all'),
        ('Drie', 'scene.keuken_relax_three'),
    )
    AUTO_LIGHT = "input_boolean.automatic_light_kitchen"
    PIR_ENTITY = "binary_sensor.pir_b_keuken"
    LIGHT_KITCHEN = "light.keuken"
    LIGHT_SENSOR = "sensor.br_irradiance"
    SUN_SENSOR = "sun.sun"
    LONG_PUSH_TIME = 0.900
    LIGHT_DELAY = 120
    IRRADIANCE_THRESHOLD = 50


    def initialize(self):
        self.hass = self.get_plugin_api("HASS")
        self.mqtt = self.get_plugin_api("MQTT")
        self.adbase = self.get_ad_api()

        self.time_zero_left = None
        self.time_zero_right = None
        self.low_ix = self.get_dim_state(
            self.LOW_INPUT_SELECT,
            self.LOW_LEVELS,
        )
        self.high_ix = self.get_dim_state(
            self.HIGH_INPUT_SELECT,
            self.HIGH_LEVELS,
        )
        self.delay_timer = None

        # self.adbase.log(f"Listinging to topic: {self.TOPIC_LEFT}")

        # Listen to left switch
        self.mqtt.listen_event(
            self.push_translator_left,
            "MQTT_MESSAGE",
            topic=self.TOPIC_LEFT
        )
        # Listen to right switch
        self.mqtt.listen_event(
            self.push_translator_right,
            "MQTT_MESSAGE",
            topic=self.TOPIC_RIGHT
        )
        # Listen to motion
        self.hass.listen_state(
            self.auto_light_callback,
            self.PIR_ENTITY,
        )
        # Listen to manual change
        self.hass.listen_state(
            self.dim_level_change_callback,
            self.LOW_INPUT_SELECT,
        )
        self.hass.listen_state(
            self.dim_level_change_callback,
            self.HIGH_INPUT_SELECT,
        )


    def get_dim_state(self, entity, levels):
        level_name = self.adbase.get_state(
            entity,
            namespace='hass'
        )
        low_names = [x[0] for x in levels]
        ix = low_names.index(level_name)
        return ix


    def push_translator_left(self, event_name, data, kwargs):
        topic = data['topic']
        payload = data['payload']
        if payload == "1":
            self.time_zero_left = self.adbase.get_now_ts()
        elif payload == "0" and self.time_zero_left is not None:
            dt = self.adbase.get_now_ts() - self.time_zero_left
            self.time_zero_left = None
            self.adbase.log(f"The left push was {dt:.3f}S")
            if dt < self.LONG_PUSH_TIME:
                self.short_push_action_left()
            else:
                self.long_push_action_left()


    def short_push_action_left(self):
        light_state = self.adbase.get_state(
            self.LIGHT_KITCHEN,
            namespace='hass'
        )
        if light_state == "on":
            self.adbase.log("The light is on, rotate lights")
            self.next_high_dim_level()

        else:
            self.adbase.log("The light is off, turn on lights")
            self.turn_on_light()


    def long_push_action_left(self):
        self.adbase.log("Toggle auto-lights")
        self.hass.toggle(self.AUTO_LIGHT)


    def next_high_dim_level(self):
        self.high_ix += 1
        if self.high_ix == len(self.HIGH_LEVELS):
            self.high_ix = 0
        self.hass.select_option(
            self.HIGH_INPUT_SELECT,
            self.HIGH_LEVELS[self.high_ix][0],
        )
        self.turn_on_light()


    def turn_on_light(self):
        scene = self.HIGH_LEVELS[self.high_ix][1]
        self.hass.turn_on(scene)


    def push_translator_right(self, event_name, data, kwargs):
        topic = data['topic']
        payload = data['payload']
        if payload == "1":
            self.time_zero_right = self.adbase.get_now_ts()
        elif payload == "0" and self.time_zero_right is not None:
            dt = self.adbase.get_now_ts() - self.time_zero_right
            self.time_zero_right = None
            self.adbase.log(f"The right push was {dt:.3f}S")
            if dt < self.LONG_PUSH_TIME:
                self.short_push_action_right()
            else:
                self.long_push_action_right()


    def short_push_action_right(self):
        self.next_low_dim_level()


    def long_push_action_right(self):
        self.hass.turn_off(self.LIGHT_KITCHEN)


    def next_low_dim_level(self):
        self.low_ix += 1
        if self.low_ix == len(self.LOW_LEVELS):
            self.low_ix = 0
        self.hass.select_option(
            self.LOW_INPUT_SELECT,
            self.LOW_LEVELS[self.low_ix][0],
        )
        self.set_low_level()


    def auto_light_off(self):
        light_state = self.adbase.get_state(
            self.LIGHT_KITCHEN,
            namespace='hass'
        )
        auto_light_state = self.adbase.get_state(
            self.AUTO_LIGHT,
            namespace='hass'
        )
        if light_state == 'on' and auto_light_state == 'on':
            self.set_low_level()


    def set_low_level(self, *args, **kwargs):
        scene = self.LOW_LEVELS[self.low_ix][1]
        self.hass.turn_on(scene)
        self.adbase.log(f"scene {scene}")
        self.adbase.cancel_timer(self.delay_timer)
        self.delay_timer = None


    def auto_light_callback(self, entity, attribute, old, new, kwargs):
        auto_light_state = self.adbase.get_state(
            self.AUTO_LIGHT,
            namespace='hass'
        )
        irradiance_state = self.adbase.get_state(
            self.LIGHT_SENSOR,
            namespace='hass'
        )
        try:
            irradiance = int(irradiance_state)
        except:
            elevation = self.adbase.get_state(
                self.SUN_SENSOR,
                namespace='hass',
                attribute='elevation',
            )
            if float(elevation) < 0.05:
                irradiance = 0
            else:
                irradiance = 100
        # self.adbase.log(f"light_level: {irradiance} pir: {new}")
        if new == 'on' and auto_light_state == 'on' and irradiance < self.IRRADIANCE_THRESHOLD:
            self.turn_on_light()
            self.adbase.cancel_timer(self.delay_timer)
            self.delay_timer = None
        elif new == 'off' and auto_light_state == 'on' and self.delay_timer is None:
            self.delay_timer = self.adbase.run_in(self.set_low_level, self.LIGHT_DELAY)
        elif auto_light_state == 'off' and self.delay_timer is not None:
            self.adbase.cancel_timer(self.delay_timer)
            self.delay_timer = None


    def dim_level_change_callback(self, entity, attribute, old, new, kwargs):
        if entity == self.LOW_INPUT_SELECT:
            self.low_ix = self.get_dim_state(
                self.LOW_INPUT_SELECT,
                self.LOW_LEVELS,
            )
            pir_keuken_state = self.adbase.get_state(
                self.PIR_ENTITY,
                namespace='hass'
            )
            if self.delay_timer is None and pir_keuken_state == 'off':
                self.set_low_level()
        else:
            self.high_ix = self.get_dim_state(
                self.HIGH_INPUT_SELECT,
                self.HIGH_LEVELS,
            )
            self.turn_on_light()
            auto_light_state = self.adbase.get_state(
                self.AUTO_LIGHT,
                namespace='hass'
            )
            if self.delay_timer is None and auto_light_state == 'on':
                self.delay_timer = self.adbase.run_in(self.set_low_level, self.LIGHT_DELAY)




