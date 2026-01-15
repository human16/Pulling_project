# Pulley

Pulley is the free and open source alternative to climbing gear meant to measure pulling force.

[Installation Guide](#installation-guide)


## How it Works

This project uses a `Raspberry Pi Pico 2W` (Could possibly work with a `Raspberry Pi Pico W`, but was not tested) and a `Klau Crane Scale` (Link will be added in the future for a specific model).

By creating a BLE (Bluetooth Low Energy) connection between a Kotlin app and the Raspberry Pi to create a data transfering connect, the Raspberry Pi, which is physically connected to the crane scale, will send over the weight data to the phone companion app

## Features

In the mobile app, the data sent from the crane scale will used for different metrics and could be displayed in a graph or analyzed for different statistics. Possible future features will include friends leaderboards and builting workout plans.

## Installation Guide
Connect the Raspberry Pi to a computer and transfer the `main.py` program from the `pico` foulder onto it. In the future, a Youtube video detailing the soldering process will be uploaded and instruction will be provided.

After connecting everything properly, install the app on your phone, and once working, power on the crane scale. This should start the bluetooth connectivity sequence in the Raspberry Pi and make the crane scale discovarable through the app.

Once connected, use the product as you would use any other 
