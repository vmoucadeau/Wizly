# Wizly

Wizly est une petite application Flutter à installer sur une montre Wear OS.
Elle permet de se connecter à un compte Izly et de générer des QR codes pour payer aux Crous en France (Restos U).
Vous pouvez installer l'apk à l'aide d'ADB en Wi-Fi :
  - Connecter votre ordinateur et votre montre au même réseau Wi-Fi (avec le débogage, la montre devrait rester connectée)
  - Activer les options développeur dans les paramètres (appuyer plusieurs fois sur numéro de build)
  - Activer le débogage via Wi-Fi et récupérez l'adresse IP et le port
  - Installer ADB sur votre ordinateur (voir sur android studio)
  - Utiliser la commande adb connect ip:port pour se connecter à la montre
  - Enfin, adb install wizly.apk pour installer l'app

