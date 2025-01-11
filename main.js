import Main from './src/Main.elm'

let app = Main.init({
    node: document.getElementById('app')
})

document.getElementById('prompt').addEventListener('keydown', function(event) {
    if (event.key === "Enter") {
        event.preventDefault();
    }
});

