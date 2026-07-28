window.addEventListener('message', function(e) {
    if (e.data.action === "playSound") {
        let audio = new Audio(`sounds/${e.data.sound}.mp3`);
        audio.volume = 1.0;
        audio.play();
    }
});
