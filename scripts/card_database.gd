# Este script NÃO estende Node, é apenas um arquivo de dados.
const CARDS = {
	"Rato da Peste": {
		"id": "Newton1",
		"nome": "Rato da Peste",
		"tipo": "Criatura",
		"custo_energy": 1,
		"gera_energy": 0,
		"ataque": 1,
		"vida": 1,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/Rato da peste.png",
		"desc": "a",
		"keywords":[]
	},
	"Membro da Royal Society": {
		"id": "Newton2",
		"nome": "Membro da Royal Society",
		"tipo": "Criatura",
		"custo_energy": 2,
		"gera_energy": 0,
		"ataque": 2,
		"vida": 1,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/MembroSociety.png",
		"desc": "a",
		"keywords":[]
	},
	"Guardião da Casa da Moeda": {
		"id": "Newton3",
		"nome": "Guardião da Casa da Moeda",
		"tipo": "Criatura",
		"custo_energy": 3,
		"gera_energy": 0,
		"ataque": 2,
		"vida": 2,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/Guardia Moeda.png",
		"desc": "a",
		"keywords":[]
	},
	"Disco de Newton": {
		"id": "Newton4",
		"nome": "Disco de Newton",
		"tipo": "Criatura",
		"custo_energy": 4,
		"gera_energy": 0,
		"ataque": 3,
		"vida": 2,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/DiscoGemini.png",
		"desc": "a",
		"keywords":[]
	},
	"Canhão de Newton": {
		"id": "Newton5",
		"nome": "Canhão de Newton",
		"tipo": "Criatura",
		"custo_energy": 5,
		"gera_energy": 0,
		"ataque": 4,
		"vida": 4,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/Canhao.png",
		"desc": "Atropelar \n Calculou a velocidade de escape da Terra(30km/s), mas tudo que tinham na época eram cavalos.",
		"keywords":["Atropelar",]
	},
	"Trinity College": {
		"id": "Newton6",
		"nome": "Trinity College",
		"tipo": "Terreno",
		"custo_energy": 0,
		"gera_energy": 2,
		"ataque": 0,
		"vida": 0,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/Trinity College.png",
		"desc": "gera 2 Mo \n A estátua de Newton no Trinity College, de Roubiliac, 'é a mais bela obra de arte do Colégio, bem como a mais comovente e significativa.'",
		"keywords":[]
	},
	"Woolsthorpe Manor": {
		"id": "Newton7",
		"nome": "Woolsthorpe Manor",
		"tipo": "Terreno",
		"custo_energy": 0,
		"gera_energy": 2,
		"ataque": 0,
		"vida": 0,
		"habilidade_path": null,
		"art_path":"res://assets/ArtCards/Woolsthorpe Manor.png",
		"desc": "gera 2 Mo",
		"keywords":[]
	},
	"Início da Peste": {
		"id": "Newton8",
		"nome": "Início da Peste",
		"tipo": "feitiço",
		"custo_energy": 3,
		"gera_energy": 0,
		"ataque": 0,
		"vida": 0,
		"habilidade_path": "res://scripts/abilities/inicio_da_peste.gd",
		"art_path":"res://assets/ArtCards/Inicio da peste.png",
		"desc": "Uma criatura alvo ganha o marcador Peste (0/-1, acumula). Para cada marcador Peste em campo invoca o Rato da peste 1/1.",
		"keywords":[]
	},
	"Surto da Peste": {
		"id": "Newton9",
		"nome": "Surto da Peste",
		"tipo": "feitiço",
		"custo_energy": 4,
		"gera_energy": 0,
		"ataque": 0,
		"vida": 0,
		"habilidade_path": "res://scripts/abilities/surto_da_peste.gd",
		"art_path":"res://assets/ArtCards/SurtoDaPeste.png",
		"desc": "Destrua até duas criaturas alvo com resistência 2 ou menor.",
		"keywords":[]
	},
	"A Peste": {
		"id": "Newton10",
		"nome": "A Peste",
		"tipo": "feitiço",
		"custo_energy": 8,
		"gera_energy": 0,
		"ataque": 0,
		"vida": 0,
		"habilidade_path": "res://scripts/abilities/a_peste.gd",
		"art_path":"res://assets/ArtCards/A Peste.png",
		"desc": "Destrua todas as criaturas.\nPara cada criatura que foi destruída desta forma, invoque um Rato da Peste 1/1.\nSó pode ser usada se, um Rato da Peste ou marcador Peste, estiver em campo.",
		"keywords":[]
	},
	# Adicione mais cartas e seus atributos aqui
}

const KEYWORD_DESCRIPTIONS = {
	"Atropelar": "Se esta criatura fosse causar dano de combate suficiente para destruir seu bloqueador, ela causa o resto de seu dano ao General Oponente.",
	# Adicione mais keywords aqui
}
