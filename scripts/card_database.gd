# Este script NÃO estende Node, é apenas um arquivo de dados.

# Ordem dos atributos: [Ataque (int), Vida (int), Descrição (String), Tipo (String), Custo de Energia (int), Geração de Energia (int)]
const CARDS = {
	"Rato da Peste": [1, 1, "a",  "Criatura", 1, 0, null],
	"Membro da Royal Society": [2, 1, "a", "Criatura", 2, 0, null],
	"Guardião da Casa da Moeda": [2, 2, "a", "Criatura", 3, 0, null],
	"Disco de Newton": [3, 2, "a", "Criatura", 4, 0, null],
	"Canhão de Newton": [4, 4, "a", "Criatura", 5, 0, null],
	"Trinity College": [0,0,"gera 2", "Terreno",0,2, null],
	"Woolsthorpe Manor": [0,0,"gera 2", "Terreno",0,2, null],
	"Início da Peste": [0,0,"Uma criatura alvo ganha o marcador Peste (0/-1). Para cada marcador Peste em campo invoca o Rato da peste", "feitiço",3,0, "res://scripts/abilities/inicio_da_peste.gd"],
	"Surto da Peste": [0,0,"Destrua até duas criaturas alvo com resistência 2 ou menor.", "feitiço",4,0, "res://scripts/abilities/surto_da_peste.gd"], # NOVO
	"A Peste": [0,0,"Destrua todas as criaturas. Para cada... (ver desc)", "feitiço",8,0, "res://scripts/abilities/a_peste.gd"], # NOVO

	# Adicione mais cartas e seus atributos aqui
}

# Caminhos das imagens das cartas (assumindo que estão na pasta assets)
# Use o formato "nome_da_carta_card.png"
const CARD_IMAGE_PATHS = {
	"Rato da Peste": "res://assets/ArtCards/Rato da peste.png",
	"Membro da Royal Society": "res://assets/ArtCards/MembroSociety.png",
	"Guardião da Casa da Moeda": "res://assets/ArtCards/Guardia Moeda.png",
	"Disco de Newton": "res://assets/ArtCards/DiscoGemini.png",
	"Canhão de Newton":"res://assets/ArtCards/Canhao.png",
	"Trinity College":"res://assets/ArtCards/Trinity College.png",
	"Woolsthorpe Manor":"res://assets/ArtCards/Woolsthorpe Manor.png",
	"Início da Peste":"res://assets/ArtCards/Inicio da peste.png",
	"Surto da Peste":"res://assets/ArtCards/SurtoDaPeste.png",
	"A Peste":"res://assets/ArtCards/A Peste.png",
	
}
