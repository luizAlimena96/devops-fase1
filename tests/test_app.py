import pytest

from app.app import create_app


@pytest.fixture
def client():
    """Cria um cliente de teste isolado para cada caso."""
    app = create_app()
    app.config["TESTING"] = True
    with app.test_client() as test_client:
        yield test_client


def test_health_retorna_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_lista_inicia_vazia(client):
    resp = client.get("/items")
    assert resp.status_code == 200
    assert resp.get_json() == []


def test_cria_item_com_sucesso(client):
    resp = client.post("/items", json={"name": "teclado"})
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["name"] == "teclado"
    assert body["id"] == 1


def test_cria_item_sem_nome_retorna_400(client):
    resp = client.post("/items", json={})
    assert resp.status_code == 400
    assert "error" in resp.get_json()


def test_busca_item_existente(client):
    criado = client.post("/items", json={"name": "monitor"}).get_json()
    resp = client.get(f"/items/{criado['id']}")
    assert resp.status_code == 200
    assert resp.get_json()["name"] == "monitor"


def test_busca_item_inexistente_retorna_404(client):
    resp = client.get("/items/999")
    assert resp.status_code == 404


def test_remove_item_existente(client):
    criado = client.post("/items", json={"name": "mouse"}).get_json()
    resp = client.delete(f"/items/{criado['id']}")
    assert resp.status_code == 204

    confirma = client.get(f"/items/{criado['id']}")
    assert confirma.status_code == 404


def test_remove_item_inexistente_retorna_404(client):
    resp = client.delete("/items/999")
    assert resp.status_code == 404
