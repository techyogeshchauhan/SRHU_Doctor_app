import { config } from '../src/config.js';
import { closeDatabase, connectToDatabase, getDiseasesCollection } from '../src/db.js';

const initialDiseases = [
  { code: 'respiratory_distress', name: 'Respiratory Distress in Neonates', isActive: true },
  { code: 'rop', name: 'Retinopathy of Prematurity', isActive: true },
  { code: 'ancs', name: 'Antenatal Corticosteroids for Preterm Birth', isActive: true },
  { code: 'neonatal_sepsis', name: 'Neonatal Sepsis', isActive: false },
  { code: 'neonatal_jaundice', name: 'Neonatal Jaundice / Hyperbilirubinemia', isActive: false },
  { code: 'hypoglycemia', name: 'Neonatal Hypoglycemia', isActive: true },
  { code: 'hypothermia_thermal_care', name: 'Thermal Care and Hypothermia', isActive: false },
  { code: 'perinatal_asphyxia_hie', name: 'Perinatal Asphyxia & Hypoxic Ischemic Encephalopathy', isActive: false },
  { code: 'neonatal_seizures', name: 'Neonatal Seizures', isActive: false },
  { code: 'necrotizing_enterocolitis', name: 'Necrotizing Enterocolitis (NEC)', isActive: false },
  { code: 'congenital_heart_disease', name: 'Congenital Heart Disease Screening', isActive: false },
  { code: 'meconium_aspiration', name: 'Meconium Aspiration Syndrome', isActive: false },
  { code: 'apnea_of_prematurity', name: 'Apnea of Prematurity', isActive: false },
  { code: 'fluids_and_feeds', name: 'Fluid, Electrolyte, and Nutritional Management', isActive: false },
  { code: 'discharge_and_follow_up', name: 'High-Risk Neonate Discharge & Follow-up', isActive: false },
];

async function seed() {
  try {
    console.log('[Seed] Connecting to MongoDB...');
    await connectToDatabase();
    const diseases = getDiseasesCollection();

    console.log(`[Seed] Seeding ${initialDiseases.length} diseases...`);
    for (const d of initialDiseases) {
      await diseases.updateOne(
        { code: d.code },
        {
          $set: {
            name: d.name,
            isActive: d.isActive,
            updatedAt: new Date(),
          },
          $setOnInsert: {
            createdAt: new Date(),
          },
        },
        { upsert: true }
      );
      console.log(`  ✓ Seeded disease: ${d.code} (active: ${d.isActive})`);
    }

    console.log('[Seed] Successfully seeded all diseases!');
  } catch (err) {
    console.error('[Seed] Error during seeding:', err);
    process.exit(1);
  } finally {
    await closeDatabase();
  }
}

seed();
