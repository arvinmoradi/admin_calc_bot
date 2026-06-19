import json
from pathlib import Path

my_path = Path(__file__).parent.absolute()

MY_JSON = my_path / 'test.json'

data = json.loads(MY_JSON.read_text(encoding='utf-8'))

print(data['admin1']['admin_id'])