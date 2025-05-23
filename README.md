# CamPop
CamPop for macOS allows webhooks to pop open an RTSP Camera stream in a window

# Settings

![Screenshot of Settings Window](settings.png)

Set the RTSP URL including rtsp://

Chose your Display Duration

Set your Webhook Port if needed the Default is port 8080 

Click Configure window size and position and set your position. Click save & Close

![Screenshot of Settings Window](windowsize.png)


### Usage

Laucnh the app or set it as a login item

![Screenshot of Menubar](menubar.png)

When CamPop is armed and http://ip:8080 is hit the configured RTSP stream will popup on your screen. 
You can arm/disarm via the menu bar or by hitting http://ip:8080/arm and http://ip:8080/disarm respectively. This will also be reflected in the menu bar.
