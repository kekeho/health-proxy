let app = Elm.Main.init();

// When Session data is sent by Websocket, pass it to Elm.
socket = new WebSocket("ws://localhost:8081/socket")
socket.addEventListener("message", function(event) {
    app.ports.sessionReciever.send(event.data);
})
