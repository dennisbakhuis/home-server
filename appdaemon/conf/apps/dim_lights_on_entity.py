import hassapi as hass

class Dim_Lights_On_Entity(hass.Hass):
    """
    Dim a list of lights when a particular entity is turned on. It remembers
    the brightness setting and sets it back when the entity is turned off.

    parameters:
    ----------
    entity : str 
        The entity to listen to and dim lights when turned on.
    lights : list of str
        A list of dimable light entities to dim
    dim_levels : list of int
        A list with the same length as lights with int values (0 .. 255) as
        dim levels for the setting. 
    """

    def initialize(self):
        self.set_namespace('hass')
        self.LIGHTS = self.args["lights"]
        self.ENTITY = self.args["entity"]
        self.DIM_LEVELS = self.args["dim_levels"]

        self.brightness_memory = None

        self.listen_state(
            self.entity_change_callback, 
            self.ENTITY,
        )
        for light_entity in self.LIGHTS:
            self.listen_state(
                self.light_turn_on_callback,
                light_entity,
            )
        self.log(f"Dimable entity listerner for {self.ENTITY} started.")


    def is_entity_on(self, entity):
        entity_state = self.get_state(
            entity, 
        )
        if entity_state == 'on':
            return True
        return False       


    def get_brightness(self, entity):
        brightness = self.get_state(
            entity, 
            attribute='brightness',
        )
        return brightness


    def set_brightness(self, entity, brightness):
        self.turn_on(entity, brightness=brightness)


    def entity_change_callback(self, entity, attribute, old, new, kwargs):
        if new == 'on':
            # Dim lights that are on and store settings
            self.brightness_memory = {}
            for light_entity, dim_level in zip(self.LIGHTS, self.DIM_LEVELS):
                brightness = self.get_brightness(light_entity)
                state = self.is_entity_on(light_entity)
                self.brightness_memory[light_entity] = (state, brightness, dim_level)
                # self.log(f"SET ---> {light_entity} {state} {dim_level} {brightness} ")
                if state:
                    self.set_brightness(light_entity, dim_level)
        elif new == 'off' and self.brightness_memory is not None:
            # Set back lights that are currently on
            for light_entity, (state, previous_dim_level, set_dim_level) in self.brightness_memory.items():
                light_state = self.is_entity_on(light_entity)
                # self.log(f"BACK ---> {light_entity} {state} {light_state} {previous_dim_level} {set_dim_level}")
                if  light_state and state:
                    # This is one of the lights we dimmed before and set it back now
                    self.set_brightness(light_entity, previous_dim_level)
                if light_state and not state:
                    # Light has been turned on during watching and it previous level should be registered
                    # by turn-on-light callback listener.
                    self.set_brightness(light_entity, previous_dim_level)
            self.brightness_memory = None


    def light_turn_on_callback(self, entity, attribute, old, new, kwargs):
        if new == 'on' and self.brightness_memory is not None:
            # Light is turned on. Get current brightness and set it dim state
            (_, _, dim_level) = self.brightness_memory[entity]
            brightness = self.get_brightness(entity)
            # self.log(f"{entity} {brightness} {dim_level}")
            if brightness > dim_level:
                self.set_brightness(entity, dim_level)
            self.brightness_memory[entity] =  (True, brightness, dim_level)
            
