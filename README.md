
# The web application is deployed using Firebase Hosting.

Live application: https://smarthome-app-865f2.web.app/
 
 # Source Code Structure

The main Flutter application source code is located in:

lib/main.dart

This file contains the implementation of the Smart Home Dashboard, including:

Room and device data models.

Home Overview displaying device states and sensor information.

Individual room interfaces.

ON/OFF controls for supported devices.

REST API communication with the Spring Boot backend.

MQTT-related functionality used by the frontend.

# Smart Home – Flutter Web Application

This repository contains the Flutter/Dart frontend of the Smart Home system.

The application allows users to monitor room conditions, view device states, and control supported Smart Home devices through a web browser.

The frontend communicates with a Java Spring Boot backend deployed on Railway through REST APIs and uses MQTT communication through the HiveMQ broker.




