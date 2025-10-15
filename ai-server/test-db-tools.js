/**
 * Test Database-First Tools via NATS
 */

import { createStandardTools } from './src/tools/nats-tools.ts';

async function testDatabaseTools() {
  console.log('🧪 Testing Database-First Tools\n');

  try {
    // Get tools (NATS connection managed internally)
    console.log('1️⃣ Creating standard tools...');
    const tools = createStandardTools();
    console.log('✅ Tools created:', Object.keys(tools.essential).join(', '), '\n');

    // Test 1: List code files
    console.log('3️⃣ Test 1: List code files');
    try {
      const listResult = await tools.essential.listCodeFiles.execute({
        codebaseId: 'singularity',
        language: 'elixir'
      });
      console.log('✅ List files result:', JSON.stringify(listResult, null, 2).substring(0, 200) + '...\n');
    } catch (error) {
      console.error('❌ List files failed:', error.message, '\n');
    }

    // Test 2: Get code file
    console.log('4️⃣ Test 2: Get code file');
    try {
      const getResult = await tools.essential.getCode.execute({
        path: 'lib/singularity/tools/database_tools_executor.ex',
        codebaseId: 'singularity',
        includeSymbols: true
      });
      console.log('✅ Get code result:', JSON.stringify(getResult, null, 2).substring(0, 300) + '...\n');
    } catch (error) {
      console.error('❌ Get code failed:', error.message, '\n');
    }

    // Test 3: Search code
    console.log('5️⃣ Test 3: Search code');
    try {
      const searchResult = await tools.essential.searchCode.execute({
        query: 'database tools',
        limit: 3,
        codebaseId: 'singularity'
      });
      console.log('✅ Search result:', JSON.stringify(searchResult, null, 2).substring(0, 300) + '...\n');
    } catch (error) {
      console.error('❌ Search failed:', error.message, '\n');
    }

    console.log('🎉 All tests completed!');
    process.exit(0);

  } catch (error) {
    console.error('💥 Test failed:', error);
    process.exit(1);
  }
}

testDatabaseTools();
