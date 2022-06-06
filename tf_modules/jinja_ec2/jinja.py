from jinja2 import Environment, FileSystemLoader
import json
  
f = open('./input.tfvars.json')
data = json.load(f)
file_loader = FileSystemLoader('.')
env = Environment(loader=file_loader)
template = env.get_template('main_template')
output = template.render(instances=data['instances'])
print(output)
f = open("main.tf", "w")
f.write(output)
f.close()