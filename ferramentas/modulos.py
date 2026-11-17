"""Extrai e reembute os módulos Fechamento e Caixa do index.html.

Uso:
  python -I ferramentas/modulos.py extrair   -> grava modulos/fechamento.html e modulos/caixa.html
  python -I ferramentas/modulos.py embutir   -> recodifica os módulos em base64 dentro do index.html
"""
import base64, pathlib, re, sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
INDEX = RAIZ / 'index.html'
PASTA = RAIZ / 'modulos'
MODULOS = {
    'fechamento': re.compile(r"(const encoded=')([A-Za-z0-9+/=]+)(')"),
    'caixa': re.compile(r'(const code=")([A-Za-z0-9+/=]+)(")'),
}


def ler_index():
    return INDEX.read_bytes().decode('utf-8')


def extrair():
    texto = ler_index()
    PASTA.mkdir(exist_ok=True)
    for nome, padrao in MODULOS.items():
        m = padrao.search(texto)
        if not m:
            sys.exit(f'Módulo {nome} não encontrado no index.html')
        (PASTA / f'{nome}.html').write_bytes(base64.b64decode(m.group(2)))
        print(f'extraído: modulos/{nome}.html')


def embutir():
    texto = ler_index()
    for nome, padrao in MODULOS.items():
        conteudo = (PASTA / f'{nome}.html').read_bytes()
        codificado = base64.b64encode(conteudo).decode('ascii')
        texto, n = padrao.subn(lambda m: m.group(1) + codificado + m.group(3), texto, count=1)
        if n != 1:
            sys.exit(f'Módulo {nome} não encontrado no index.html')
        print(f'embutido: modulos/{nome}.html')
    INDEX.write_bytes(texto.encode('utf-8'))


if __name__ == '__main__':
    {'extrair': extrair, 'embutir': embutir}[sys.argv[1] if len(sys.argv) > 1 else '']()
