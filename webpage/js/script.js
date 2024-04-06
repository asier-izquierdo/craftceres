fetch('https://api.mcstatus.io/v2/status/java/mc.craftceres.cc')
    .then((response) => {
        if (response.ok) {
          return response.json();
        } else {
          throw new Error("NETWORK RESPONSE ERROR");
        }
      })
      .then((data) => {
        console.log(data);
        estado(data)
      });

function estado(data){

    const status = data.online;
    const players = data.players;
    
    if (status != true) {
        document.getElementById("estados").style.color="white";
        document.getElementById("estados").innerHTML="Desconectado";
        document.getElementById("estados").style.cssText += "background-color: red";
    }
    else {
       
        document.getElementById("estados").innerHTML="En línea | "+players.online+"/"+players.max;
	document.getElementById("estados").style.color="white";
	document.getElementById("estados").style.cssText += "background-color: #30d158";

    }

}

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

