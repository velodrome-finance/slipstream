export function convertTextToJson(text: string): { name: string; description: string; image: string } {
  const encodedJSON = '{' + text + '}'
  return JSON.parse(encodedJSON)
}
