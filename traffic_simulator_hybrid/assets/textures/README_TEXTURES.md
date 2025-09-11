# Texturas do Traffic Simulator 3D

## 📋 Texturas Incluídas

### 🏢 Calçadas (Sidewalks)
**Pasta:** `sidewalks/`

#### Texturas CC0 da Poly Haven
- **concrete_plain_02_diff_2k.jpg** - Textura difusa de concreto (2048x2048)
- **concrete_plain_02_nor_gl_2k.jpg** - Mapa normal OpenGL (2048x2048) 
- **concrete_plain_02_rough_2k.jpg** - Mapa de rugosidade (2048x2048)

**Fonte:** [Poly Haven](https://polyhaven.com/) - CC0 License  
**Resolução:** 2048x2048 pixels  
**Formato:** JPEG  
**Licença:** CC0 (Domínio Público)  

### 🛣️ Estradas (Roads)
**Pasta:** `roads/`

#### Texturas de Asfalto
- **asphalt_02_diff_2k.jpg** - Textura difusa de asfalto
- **asphalt_02_nor_gl_2k.jpg** - Mapa normal
- **asphalt_02_rough_2k.jpg** - Mapa de rugosidade

## 🎮 Uso no Projeto

### Implementação Automática
O sistema possui **dupla implementação**:

1. **Texturas Reais (Preferencial):**
   ```gdscript
   var concrete_texture = load("res://assets/textures/sidewalks/concrete_plain_02_diff_2k.jpg")
   ```

2. **Texturas Procedurais (Fallback):**
   ```gdscript
   var concrete_texture = TextureGenerator.create_concrete_texture(1024)
   ```

### Configuração de Material
```gdscript
sidewalk_material.albedo_texture = concrete_texture
sidewalk_material.normal_texture = concrete_normal  
sidewalk_material.roughness_texture = concrete_roughness
sidewalk_material.uv1_scale = Vector3(3.0, 3.0, 1.0)  # Tiling 3x3
```

## 📄 Licenças

### CC0 (Creative Commons Zero)
- ✅ **Uso Comercial** permitido
- ✅ **Modificação** permitida  
- ✅ **Distribuição** permitida
- ❌ **Atribuição** não obrigatória
- ❌ **Garantias** não fornecidas

### Recursos Adicionais

**Para mais texturas CC0:**
- [Poly Haven](https://polyhaven.com/textures)
- [CC0 Textures](https://cc0textures.com/)
- [FreePBR](https://freepbr.com/)
- [AmbientCG](https://ambientcg.com/)

## 🔧 Gerador Procedural

O arquivo `TextureGenerator.gd` contém:
- `create_concrete_texture()` - Difusa procedural
- `create_concrete_normal_map()` - Normal procedural
- `create_concrete_roughness_map()` - Rugosidade procedural

**Vantagens:**
- 🚀 Sem dependência de arquivos externos
- ⚡ Geração em tempo real
- 🎨 Totalmente customizável
- 📦 Projeto mais leve

## 🎯 Qualidade Visual

**Configurações Otimizadas:**
- **Resolução:** 1024x1024 (procedural) ou 2048x2048 (CC0)
- **UV Scaling:** 3x3 para realismo
- **Normal Mapping:** Ativado para detalhes
- **PBR Workflow:** Diffuse + Normal + Roughness

**Resultado:**
- ✅ Calçadas realísticas e detalhadas
- ✅ Performance otimizada  
- ✅ Compatibilidade total com Godot 4.4
- ✅ Fallback automático garantido