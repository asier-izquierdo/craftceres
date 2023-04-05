function copiado() {

    document.getElementById("copiado").classList.toggle("copiado");

}

function copiar() {
    
    var copyText = document.getElementById("mcserver").textContent;
    
    navigator.clipboard.writeText(copyText);

    copiado();

    setTimeout("copiado()", 2500);

}

function socials() {

    document.getElementById("socials").classList.toggle("aparecer");
    var estado = document.getElementById('socials').className;

    if (estado != "hidden"){
        document.getElementById("socials").classList.toggle("hidden");
    }
    else {
        document.getElementById("socials").classList.toggle("aparecer");
    }

}

