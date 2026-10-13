const fs = require('fs');

const filePath = 'C:\\Users\\silvo\\Downloads\\files\\jk-cred\\public\\index.html';
let content = fs.readFileSync(filePath, 'utf8');

// Fix AdminStub - remove extra ) in ${Empty(...)}) -> ${Empty(...)})
content = content.replace(
  /\$\{Empty\(n\[0\],'Tela em desenvolvimento','Esta seção será construída nas próximas etapas\.',Btn\('Voltar à visão geral',\{href:'#\/admin',variant:'ghost',ico:'back'\}\)\)\}/g,
  "${Empty(n[0],'Tela em desenvolvimento','Esta seção será construída nas próximas etapas.',Btn('Voltar à visão geral',{href:'#/admin',variant:'ghost',ico:'back'}))}"
);

// Fix ClientStub - remove extra ) in ${Empty(...)}) -> ${Empty(...)})
content = content.replace(
  /\$\{Empty\(ico,'Tela em desenvolvimento','Esta funcionalidade será implementada nas próximas etapas\.',Btn\('Voltar ao início',\{href:'#\/cliente',variant:'ghost',ico:'back'\}\)\}/g,
  "${Empty(ico,'Tela em desenvolvimento','Esta funcionalidade será implementada nas próximas etapas.',Btn('Voltar ao início',{href:'#/cliente',variant:'ghost',ico:'back'}))}"
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed extra parentheses in AdminStub and ClientStub');