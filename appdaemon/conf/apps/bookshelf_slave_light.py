import hassapi as hass

class Bookshelf_Slave_Light(hass.Hass):
    """
    Bookshelf Slave light follows a light. I.e. it turns on or off when 
    that light is turned on/off as well and it follows the brightness
    adjustments. 

    However, it will be turned off when the tv is turned on, and turned
    on when the tv is turned off. Of course only, when the slave lights 
    are on.
    """

    MASTER_LIGHT = 'light.retrolamp'
    LIGHT = 'light.boekenkast'
    TV = 'media_player.lg_television'
    BRIGHTNESS_CORRECTION = 0.6


    def initialize(self):
        self.set_namespace('hass')
        self.listen_state(
            self.master_light_callback, 
            self.MASTER_LIGHT,
            attribute='all',
        )
        self.listen_state(
            self.television_callback, 
            self.TV,
        )
        self.log("Boekenkast slave light online")


    def is_entity_on(self, entity):
        entity_state = self.get_state(
            entity, 
        )
        if entity_state == 'on':
            return True
        return False       


    def is_light_on(self):
        return self.is_entity_on(self.LIGHT)


    def is_tv_on(self):
        return self.is_entity_on(self.TV)


    def is_master_on(self):
        return self.is_entity_on(self.MASTER_LIGHT)


    def get_brightness(self):
        brightness = self.get_state(
            self.MASTER_LIGHT, 
            attribute='brightness',
        )
        # self.log(f"**-> {type(brightness)}")
        corrected_brightness = int(self.BRIGHTNESS_CORRECTION * brightness)
        return corrected_brightness     


    def parse_entity_change(self, old, new):
        if old['state'] != new['state']:
            return ('state', old['state'], new['state'])
        if old['attributes']['brightness'] != new['attributes']['brightness']:
            return ('brightness', old['attributes']['brightness'], new['attributes']['brightness'])
        return ('None', None, None)


    def master_light_callback(self, entity, attribute, old, new, kwargs):
        (change, old_value, new_value) = self.parse_entity_change(old, new)
        # self.log(f"**-> {change}, {old_value}, {new_value}")
        if change == 'state' and new_value == 'on':
            if not self.is_light_on() and not self.is_tv_on():
                # Turn on  and match brightness
                brightness = self.get_brightness()
                self.turn_on(self.LIGHT,  brightness=brightness)
        elif change == 'state' and new_value == 'off':
            if self.is_light_on():
                self.turn_off(self.LIGHT)
        elif change == 'brightness':
            if self.is_light_on():
                corrected_brightness = int(self.BRIGHTNESS_CORRECTION * new_value)
                self.turn_on(self.LIGHT, brightness=corrected_brightness)


    def television_callback(self, entity, attribute, old, new, kwargs):
        if new == 'on' and self.is_light_on():
            self.turn_off(self.LIGHT)
        elif new == 'off' and self.is_master_on():
            brightness = self.get_brightness()
            self.turn_on(self.LIGHT, brightness=brightness)

