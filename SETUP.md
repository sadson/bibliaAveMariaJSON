# Bíblia Ave Maria — Setup

## Pré-requisitos

- Flutter SDK 3.32+
- Node.js 18+
- Git

## 1. Gerar assets (uma vez)

```bash
cd scripts
npm install
npm run generate:db         # Gera bible_app/assets/data/bible.db (~9 MB)
npm run generate:embeddings # Baixa modelo ONNX ~22 MB, gera embeddings ~12 MB
```

> **Nota:** O script de embeddings faz download do modelo `all-MiniLM-L6-v2` da HuggingFace (~22 MB) na primeira execução. Após isso, o modelo fica em cache e o script também copia automaticamente os arquivos para `bible_app/assets/models/`.

## 2. Instalar dependências Flutter

```bash
cd bible_app
flutter pub get
```

## 3. Rodar o app

```bash
flutter run
```

## Arquitetura

```
scripts/
├── generate_db.js          # JSON → SQLite (bible.db) com FTS5
└── generate_embeddings.js  # Versículos → int8 embeddings + copia modelo ONNX

bible_app/
├── lib/
│   ├── core/               # Tema (Material 3, azul + dourado)
│   ├── data/
│   │   ├── db/             # Schema Drift (Books, Chapters, Verses, Bookmarks)
│   │   └── repository/     # BibleRepository + Riverpod providers
│   ├── features/
│   │   ├── books/          # Lista AT/NT com 73 livros
│   │   ├── chapters/       # Grid de capítulos
│   │   ├── reader/         # Leitura com nav. entre capítulos + favoritos
│   │   ├── search/         # Busca textual (FTS5) e semântica
│   │   └── bookmarks/      # Favoritos com swipe-to-delete
│   └── services/
│       ├── embedding_service.dart  # Carrega embeddings, busca coseno em isolate
│       └── tokenizer.dart          # BERT WordPiece tokenizer em Dart puro
└── assets/
    ├── data/bible.db               # SQLite com 73 livros, 35.450 versículos
    ├── embeddings/
    │   ├── verses_embeddings.bin   # int8 quantizado, 384 dims × 35K = ~12 MB
    │   └── verse_ids.bin           # IDs dos versículos
    └── models/
        ├── all_minilm_l6_v2.onnx   # Modelo para embedding de queries (~22 MB)
        └── tokenizer_vocab.txt     # Vocabulário BERT WordPiece
```

## Busca Semântica (como funciona)

1. **Build-time**: `generate_embeddings.js` processa todos os 35.450 versículos com `all-MiniLM-L6-v2` e salva vetores int8 quantizados (~12 MB).
2. **Runtime query**: O `EmbeddingService` carrega o modelo ONNX localmente, tokeniza a query com o `BertTokenizer` em Dart e gera um embedding de 384 dimensões.
3. **Busca**: Similaridade coseno em Dart isolate sobre todos os vetores → retorna top-20 versículos mais relevantes em ~50-100ms.

Tudo funciona **100% offline** após a primeira configuração.
