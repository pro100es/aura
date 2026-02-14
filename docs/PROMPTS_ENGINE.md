# Aura AI Prompts Engine

## 🎨 Prompt Architecture

### Global Quality Wrapper
Добавляется автоматически к каждому запросу:

```json
{
  "global_positive_prefix": "professional commercial photography, high-end editorial, shot on 35mm lens, f/1.8, incredibly detailed, realistic skin textures, natural lighting, sharp focus, 8k resolution, cinematic composition",
  
  "global_negative_prompt": "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, (mutated hands and fingers:1.4), disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation, watermark, text, logos, grainy, low quality, plastic skin, doll-like, over-sharpened, cartoon, anime, 3d render"
}
```

---

## 📚 Style Presets Library

```json
{
  "presets": [
    {
      "slug": "old-money-paris",
      "name": "Old Money",
      "mode": "persona",
      "prompt_core": "A person in a minimalist chic outfit, sitting at a classic Parisian cafe, beige and cream color palette, soft afternoon sunlight through cafe windows, elegant atmosphere, blurred background of Haussmann architecture, expensive aesthetic, quiet luxury, natural skin tone, editorial magazine quality",
      "face_preservation_strength": 0.85,
      "composition_hints": "medium shot, subject in focus, soft bokeh background, rule of thirds composition",
      "lighting_profile": "natural window light, soft shadows, golden hour warmth",
      "parameters": {
        "guidance_scale": 3.5,
        "num_inference_steps": 28,
        "ip_adapter_scale": 0.8
      }
    },
    
    {
      "slug": "urban-night-tokyo",
      "name": "Urban Night",
      "mode": "persona",
      "prompt_core": "Night photography in bustling Tokyo street, cinematic neon lighting, reflections of red and blue city lights on wet pavement, high contrast, street style aesthetic, busy metropolitan background with bokeh effects, sharp details on subject, moody cyberpunk atmosphere",
      "face_preservation_strength": 0.82,
      "composition_hints": "portrait orientation, shallow depth of field, neon signs in background",
      "lighting_profile": "neon practical lights, rim lighting, deep shadows for drama",
      "parameters": {
        "guidance_scale": 4.0,
        "num_inference_steps": 30,
        "ip_adapter_scale": 0.75
      }
    },
    
    {
      "slug": "scandi-minimalist",
      "name": "Scandi Minimalist",
      "mode": "persona",
      "prompt_core": "Clean minimalist Scandinavian interior, person in natural linen clothing, bright natural daylight from large window, white walls and light oak wood textures, clean lines, organic aesthetic, soft shadows, airy and fresh atmosphere, high-end lifestyle photography, serene mood",
      "face_preservation_strength": 0.88,
      "composition_hints": "environmental portrait, negative space, balanced composition",
      "lighting_profile": "diffused natural window light, no harsh shadows, bright and airy",
      "parameters": {
        "guidance_scale": 3.0,
        "num_inference_steps": 25,
        "ip_adapter_scale": 0.85
      }
    },
    
    {
      "slug": "editorial-vogue",
      "name": "Editorial Vogue",
      "mode": "persona",
      "prompt_core": "High fashion editorial photoshoot, dramatic studio lighting setup, harsh directional light creating deep shadows, stark monochromatic background or bold single color, avant-garde aesthetic, sharp focus on eyes and facial features, grainy film texture, 90s Vogue magazine style, confident pose",
      "face_preservation_strength": 0.75,
      "composition_hints": "tight crop, dramatic angles, high contrast",
      "lighting_profile": "hard key light, fill light minimal, strong shadows for dimension",
      "parameters": {
        "guidance_scale": 4.5,
        "num_inference_steps": 32,
        "ip_adapter_scale": 0.7
      }
    },
    
    {
      "slug": "analog-film-90s",
      "name": "Analog Film 90s",
      "mode": "persona",
      "prompt_core": "Vintage 90s film photography aesthetic, shot on Kodak Portra 400, warm natural skin tones, visible film grain texture, soft lens flare from sunlight, nostalgic vibe, authentic candid moment, raw unposed photography, natural imperfections, slightly faded colors, timeless feel",
      "face_preservation_strength": 0.90,
      "composition_hints": "candid snapshot style, natural framing, imperfect composition adds authenticity",
      "lighting_profile": "natural outdoor light, soft and flattering, golden hour preferred",
      "parameters": {
        "guidance_scale": 3.2,
        "num_inference_steps": 26,
        "ip_adapter_scale": 0.88
      }
    },
    
    {
      "slug": "product-luxury",
      "name": "Luxury Product",
      "mode": "object",
      "prompt_core": "High-end product photography, luxury item on marble surface, studio lighting setup, clean white or black background, perfect reflections, premium aesthetic, sharp focus on product, commercial photography quality",
      "structure_preservation": "canny_edge",
      "lighting_profile": "three-point studio lighting, soft box diffusion",
      "parameters": {
        "guidance_scale": 3.8,
        "num_inference_steps": 30,
        "controlnet_conditioning_scale": 0.7
      }
    }
  ]
}
```

---

## 🧠 Smart Prompt Builder (TypeScript)

```typescript
// prompts/PromptBuilder.ts
import { Preset } from './types';

class PromptBuilder {
  private globalPrefix =
    "professional commercial photography, high-end editorial, shot on 35mm lens, f/1.8, incredibly detailed, realistic skin textures, natural lighting, sharp focus, 8k resolution, cinematic composition";
    
  private globalNegative =
    "(deformed, distorted, disfigured:1.3), poorly drawn, bad anatomy, wrong anatomy, extra limb, missing limb, floating limbs, (mutated hands and fingers:1.4), disconnected limbs, mutation, mutated, ugly, disgusting, blurry, amputation, watermark, text, logos, grainy, low quality, plastic skin, doll-like, over-sharpened";

  buildFinalPrompt(preset: Preset, customAdditions?: string): string {
    const parts = [
      this.globalPrefix,
      preset.prompt_core,
      preset.composition_hints,
      preset.lighting_profile,
      customAdditions
    ].filter(Boolean);

    return parts.join(', ');
  }

  buildNegativePrompt(preset: Preset): string {
    return this.globalNegative;
  }

  buildReplicateInput(
    preset: Preset,
    imageUrl: string,
    customPrompt?: string
  ) {
    const finalPrompt = this.buildFinalPrompt(preset, customPrompt);
    const negativePrompt = this.buildNegativePrompt(preset);

    if (preset.mode === 'persona') {
      // Use InstantID model
      return {
        model: "zsxkib/instant-id:6c8f5e3aeb3a15f91c43c6fb31ebdbd06e3957efa38ce89c696edf2a75012f5c",
        input: {
          image: imageUrl,
          prompt: finalPrompt,
          negative_prompt: negativePrompt,
          ip_adapter_scale: preset.parameters.ip_adapter_scale,
          guidance_scale: preset.parameters.guidance_scale,
          num_inference_steps: preset.parameters.num_inference_steps,
          sdxl_weights: "juggernaut_reborn",
          identity_preservation: preset.face_preservation_strength
        }
      };
    } else if (preset.mode === 'object') {
      // Use ControlNet model
      return {
        model: "jagilley/controlnet-canny:aff48af9c68d162388d230a2ab003f68d2638d88307bdaf1c2f1ac95079c9613",
        input: {
          image: imageUrl,
          prompt: finalPrompt,
          negative_prompt: negativePrompt,
          structure: preset.structure_preservation,
          guidance_scale: preset.parameters.guidance_scale,
          num_inference_steps: preset.parameters.num_inference_steps
        }
      };
    }
  }

  // A/B Testing: Generate 4 variants
  generateBatchVariants(preset: Preset, imageUrl: string) {
    const variants = [
      { name: 'safe_match', guidance: 2.5, steps: 25 },
      { name: 'editorial', guidance: 4.0, steps: 30 },
      { name: 'lifestyle', guidance: 3.0, steps: 26 },
      { name: 'artistic', guidance: 5.0, steps: 32 }
    ];

    return variants.map(v => {
      const modifiedPreset = {
        ...preset,
        parameters: {
          ...preset.parameters,
          guidance_scale: v.guidance,
          num_inference_steps: v.steps
        }
      };
      return {
        variant_name: v.name,
        input: this.buildReplicateInput(modifiedPreset, imageUrl)
      };
    });
  }
}

export default new PromptBuilder();
```

---

## 🎯 Usage Examples for Cursor

### Пример 1: Генерация для InstantID
```typescript
import PromptBuilder from './prompts/PromptBuilder';
import { presetsData } from './prompts/presets.json';

const preset = presetsData.presets.find(p => p.slug === 'old-money-paris');
const imageUrl = 'https://storage.supabase.co/uploads/user_photo.jpg';

const replicateInput = PromptBuilder.buildReplicateInput(preset, imageUrl);

const response = await replicate.predictions.create(replicateInput);
```

### Пример 2: A/B Testing (4 варианта)
```typescript
const variants = PromptBuilder.generateBatchVariants(preset, imageUrl);

const predictions = await Promise.all(
  variants.map(v => replicate.predictions.create(v.input))
);

// Save variant names to DB for later identification
await db.generations.create({
  variants: predictions.map((p, i) => ({
    replicate_id: p.id,
    variant_name: variants[i].variant_name
  }))
});
```

---

## 📝 Инструкции для Cursor

```
@PROMPTS_ENGINE:
1. Загрузи presets.json как константу в бэкенде
2. Используй PromptBuilder class для всех вызовов Replicate
3. Для режима Persona всегда используй InstantID модель
4. Для Object mode используй ControlNet с structure_preservation
5. В ответe API возвращай variant_name для фронтенда
```
