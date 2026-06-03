"""API REST simples em Flask para o projeto DevOps - Fase 1.

Expoe um CRUD em memoria de "itens" e um endpoint de health check,
usados como alvo da pipeline de CI e da infraestrutura provisionada
via Terraform.
"""

from flask import Flask, jsonify, request


def create_app():
    """Cria e configura a instancia da aplicacao Flask (app factory)."""
    app = Flask(__name__)

    # Armazenamento em memoria. Suficiente para demonstrar a API e os testes.
    items = {}
    sequence = {"next_id": 1}

    @app.route("/health", methods=["GET"])
    def health():
        """Endpoint usado por checagens de saude e monitoramento."""
        return jsonify({"status": "ok"}), 200

    @app.route("/items", methods=["GET"])
    def list_items():
        """Lista todos os itens cadastrados."""
        return jsonify(list(items.values())), 200

    @app.route("/items/<int:item_id>", methods=["GET"])
    def get_item(item_id):
        """Retorna um item especifico pelo seu id."""
        item = items.get(item_id)
        if item is None:
            return jsonify({"error": "item nao encontrado"}), 404
        return jsonify(item), 200

    @app.route("/items", methods=["POST"])
    def create_item():
        """Cria um novo item. Espera um JSON com o campo 'name'."""
        data = request.get_json(silent=True) or {}
        name = data.get("name")
        if not name:
            return jsonify({"error": "o campo 'name' e obrigatorio"}), 400

        item = {"id": sequence["next_id"], "name": name}
        items[item["id"]] = item
        sequence["next_id"] += 1
        return jsonify(item), 201

    @app.route("/items/<int:item_id>", methods=["DELETE"])
    def delete_item(item_id):
        """Remove um item pelo seu id."""
        if item_id not in items:
            return jsonify({"error": "item nao encontrado"}), 404
        del items[item_id]
        return "", 204

    return app


# Instancia usada pelo servidor de aplicacao (gunicorn app.app:app).
app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
