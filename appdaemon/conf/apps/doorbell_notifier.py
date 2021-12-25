#####################################################################
# Doorbell notifier                                                 #
#####################################################################
# Send telegram message when someone uses my doorbell               #
#                                                                   #
# I have a mechanical doorbell (literaly a bell on a string) and    #
# connected a window sensor to the string. When it changes state    #
# from open to close, I want to send a 'ding dong' message to       #
# my HASS telegram group.                                           #
#                                                                   #
# EXAMPLE entry for appdaemon.cfg                                   #
#                                                                   #
# [doorbell_notifier]                                               #
# module = doorbell_notifier                                        #
# class = DoorbellNotifier                                          #
# doorbell_sensor = binary_sensor.deurbel                           #
# notify_service = notify.everybody
#####################################################################
# Author: Dennis Bakhuis                                            #
# Date: 2021 November 15                                            #
#####################################################################
import hassapi as hass

class DoorbellNotifier(hass.Hass):

    TITLE = 'Doorbell notifier'
    MESSAGE = 'Ding dong!'

    def initialize(self):
        self.set_namespace('hass')

        self.doorbell_sensor = self.args['doorbell_sensor']
        self.notify_service = self.args['notify_service']
        if 'title' in self.args:
            self.title = self.args['title']
        else:
            self.title = self.TITLE
        if 'message' in self.args:
            self.message = self.args['message']
        else:
            self.message = self.MESSAGE


        self.listen_state(
            self.doorbell_callback,
            self.doorbell_sensor,
        )

        self.log("Doorbell notifier online")


    def doorbell_callback(self, entity, attribute, old, new, kwargs):
        if new == 'off':  # My default is 'on' == 'open'
            # self.log("Will do a ding dong!")
            self.send_message()


    def send_message(self):
        # self.log("Ding dong!")
        self.notify(
            self.message,
            title=self.title,
            name=self.notify_service,
        )
