function AssetBrowser::createMaterialAsset(%this)
{
   %assetName = AssetBrowser.newAssetSettings.assetName;
   
   %moduleName = AssetBrowser.newAssetSettings.moduleName;
   %modulePath = "data/" @ %moduleName;
   
   %assetPath = AssetBrowser.dirHandler.currentAddress @ "/";   
   
   %tamlpath = %assetPath @ %assetName @ ".asset.taml";
   %sgfPath = %assetPath @ %assetName @ ".sgf";
   
   %asset = new MaterialAsset()
   {
      AssetName = %assetName;
      versionId = 1;
      shaderData = "";
      shaderGraph = %sgfPath;
   };
   
   TamlWrite(%asset, %tamlpath);
   
   %moduleDef = ModuleDatabase.findModule(%moduleName, 1);
	AssetDatabase.addDeclaredAsset(%moduleDef, %tamlpath);

	AssetBrowser.loadFilters();
	
	%treeItemId = AssetBrowserFilterTree.findItemByName(%moduleName);
	%smItem = AssetBrowserFilterTree.findChildItemByName(%treeItemId, "Materials");
	
	AssetBrowserFilterTree.onSelect(%smItem);
   
	return %tamlpath;
}

function AssetBrowser::editMaterialAsset(%this, %assetDef)
{
   %assetDef.materialDefinitionName.reload();
   
   EditorGui.setEditor(MaterialEditorPlugin);
   
   MaterialEditorGui.currentMaterial = %assetDef.materialDefinitionName;
   MaterialEditorGui.setActiveMaterial( %assetDef.materialDefinitionName );
   
   AssetBrowser.hideDialog();
}

//Renames the asset
function AssetBrowser::renameMaterialAsset(%this, %assetDef, %newAssetName)
{
   %newFilename = renameAssetLooseFile(%assetDef.scriptPath, %newAssetName);
   
   if(!%newFilename $= "")
      return;
      
   %assetDef.scriptPath = %newFilename;
   %assetDef.saveAsset();
   
   renameAssetFile(%assetDef, %newAssetName);
}

//Deletes the asset
function AssetBrowser::deleteMaterialAsset(%this, %assetDef)
{
   AssetDatabase.deleteAsset(%assetDef.getAssetId(), true);
}

//Moves the asset to a new path/module
function AssetBrowser::moveMaterialAsset(%this, %assetDef, %destination)
{
   %currentModule = AssetDatabase.getAssetModule(%assetDef.getAssetId());
   %targetModule = AssetBrowser.getModuleFromAddress(%destination);
   
   %newAssetPath = moveAssetFile(%assetDef, %destination);
   
   if(%newAssetPath $= "")
      return false;

   moveAssetLooseFile(%assetDef.scriptPath, %destination);
   
   AssetDatabase.removeDeclaredAsset(%assetDef.getAssetId());
   AssetDatabase.addDeclaredAsset(%targetModule, %newAssetPath);
}

function AssetBrowser::prepareImportMaterialAsset(%this, %assetItem)
{
   ImportActivityLog.add("Preparing Material for Import: " @ %assetItem.assetName);
   
   //Iterate over to find appropriate images for
         
   //Fetch just the fileBase name
   %fileDir = filePath(%assetItem.filePath);
   %fileName = fileBase(%assetItem.filePath);
   %fileExt = fileExt(%assetItem.filePath);
   
   %assetItem.generatedAsset = true;
   
   //Check if we need to filter this material out or not
   if(getAssetImportConfigValue("Materials/IgnoreMaterials", "") !$= "")
   {
      %ignoredMatNamesCount = getTokenCount(getAssetImportConfigValue("Materials/IgnoreMaterials", ""), ",;");
      for(%i=0; %i < %ignoredMatNamesCount; %i++)
      {
        %ignoreName = getToken(getAssetImportConfigValue("Materials/IgnoreMaterials", ""), ",;", %i);
        
        if(strIsMatchExpr(%ignoreName, %fileName))
        {
            //We fit the bill, ignore this material and skip it
            %assetItem.skip = true;
            
            ImportActivityLog.add(%assetItem.assetName @ " has been ignored due to config Materials/IgnoreMaterials settings");
            
            return;  
        }
      }
   }
   
   if(getAssetImportConfigValue("Materials/PopulateMaterialMaps", "1") == 1)
   {
      ImportActivityLog.add("Attempting to Auto-Populate Material Maps");
      
      for(%i=0; %i < %assetItem.childAssetItems.count(); %i++)
      {
         %childAssetItem = %assetItem.childAssetItems.getKey(%i);
         
         if(!isObject(%childAssetItem) || %childAssetItem.skip || %childAssetItem.processed == true || %childAssetItem.assetType !$= "ImageAsset")
            return;
            
         if(%childAssetItem.imageType $= "Albedo")
         {
            %assetItem.diffuseImageAsset = %childAssetItem;
         }
      }
      
      /*%materialItemId = ImportAssetTree.findItemByObjectId(%assetItem);
      
      if(%assetItem.diffuseImageAsset $= "")
      {
         %diffuseTypeSuffixes = getAssetImportConfigValue("Images/DiffuseTypeSuffixes", "");
         
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %diffuseTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated Diffuse Map Image Asset via file: " @ %targetFilePath);
            
            %diffuseAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.diffuseImageAsset = %diffuseAsset;
         }
      }
      
      //Now, iterate over our comma-delimited suffixes to see if we have any matches. We'll use the first match in each case, if any.
      if(%assetItem.normalImageAsset $= "")
      {
         %normalTypeSuffixes = getAssetImportConfigValue("Images/NormalTypeSuffixes", "");
         
         //First, normal map
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %normalTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated Normal Map Image Asset via file: " @ %targetFilePath);
            
            %normalAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.normalImageAsset = %normalAsset;
         }
      }
      
      if(%assetItem.metalImageAsset $= "")
      {
         %metalnessTypeSuffixes = getAssetImportConfigValue("Images/MetalnessTypeSuffixes", "");
         
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %metalnessTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated Metalness Map Image Asset via file: " @ %targetFilePath);
            
            %metalAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.metalImageAsset = %metalAsset;
         }
      }
      
      if(%assetItem.roughnessImageAsset $= "")
      {
         %roughnessTypeSuffixes = getAssetImportConfigValue("Images/RoughnessTypeSuffixes", "");
         
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %roughnessTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated Roughness Map Image Asset via file: " @ %targetFilePath);
            
            %roughnessAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.roughnessImageAsset = %roughnessAsset;
         }
      }
      
      if(%assetItem.smoothnessImageAsset $= "")
      {
         %smoothnessTypeSuffixes = getAssetImportConfigValue("Images/SmoothnessTypeSuffixes", "");
         
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %smoothnessTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated Smoothness Map Image Asset via file: " @ %targetFilePath);
            
            %smoothnessAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.SmoothnessImageAsset = %smoothnessAsset;
         }
      }
      
      if(%assetItem.AOImageAsset $= "")
      {
         %aoTypeSuffixes = getAssetImportConfigValue("Images/AOTypeSuffixes", "");
         
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %aoTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated AO Map Image Asset via file: " @ %targetFilePath);
            
            %AOAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.AOImageAsset = %AOAsset;
         }
      }
      
      if(%assetItem.compositeImageAsset $= "")
      {
         %compositeTypeSuffixes = getAssetImportConfigValue("Images/CompositeTypeSuffixes", "");
         
         %targetFilePath = %this.findMaterialMapFileWSuffix(%fileDir, %fileName, %fileExt, %compositeTypeSuffixes);
         
         if(%targetFilePath !$= "")
         {
            ImportActivityLog.add("Auto-Populated Composite Map Image Asset via file: " @ %targetFilePath);
            
            %compositeAsset = AssetBrowser.addImportingAsset("ImageAsset", %targetFilePath, %assetItem);
            %assetItem.compositeImageAsset = %compositeAsset;
         }
      }
      
      //If after the above we didn't find any, check to see if we should be generating one
      if(%assetItem.compositeImageAsset $= "" && 
         (%assetItem.roughnessImageAsset !$= "" || %assetItem.AOImageAsset !$= "" || %assetItem.metalnessImageAsset !$= "") &&
         getAssetImportConfigValue("Materials/CreateComposites", "1") == 1)
      {
         %assetItem.roughnessImageAsset.skip = true;
         %assetItem.AOImageAsset.skip = true;
         %assetItem.metalnessImageAsset.skip = true;
         
         %compositeAssetPath = AssetBrowser.dirHandler.currentAddress @ "/";
         %saveAsPath = %compositeAssetPath @ "/" @ %assetItem.assetName @ "_composite.png";
         
         ImportActivityLog.add("Auto-Generated Composite Map from ORM maps");
         
         %compositeAsset = AssetBrowser.addImportingAsset("ImageAsset", "", %assetItem, %assetItem.assetName @ "_composite");
         %compositeAsset.generatedAsset = true;
         %compositeAsset.filePath = %saveAsPath;
         
         %assetItem.compositeImageAsset = %compositeAsset;
      }*/
   }
   
   %assetItem.processed = true;
   
   refreshImportAssetWindow();
}

function AssetBrowser::findMaterialMapFileWSuffix(%this, %fileDir, %filename, %fileExt, %suffixesList)
{
   %listCount = getTokenCount(%suffixesList, ",;");
   
   %foundFile = 0;
   %filePath = "";
   for(%i=0; %i < %listCount; %i++)
   {
      %entryText = getToken(%suffixesList, ",;", %i);
      
      if(%fileExt $= "")
      {
         %filePath = findFirstFile(%fileDir @ "/" @ %filename @ %entryText @ ".*");
         %foundFile = isFile(%filePath);
      }
      else
      {
         %filePath = %fileDir @ "/" @ %filename @ %entryText @ %fileExt;
         %foundFile = isFile(%filePath);
      }
      
      if(%foundFile)
      {
         return %filePath;
      }
   }
   
   return "";
}

function AssetBrowser::importMaterialAsset(%this, %assetItem)
{
   %moduleName = AssetImportTargetModule.getText();
   
   %assetType = %assetItem.AssetType;
   %filePath = %assetItem.filePath;
   %assetName = %assetItem.assetName;
   %assetImportSuccessful = false;
   %assetId = %moduleName@":"@%assetName;
   
   %assetPath = AssetBrowser.dirHandler.currentAddress @ "/";
   %tamlpath = %assetPath @ %assetName @ ".asset.taml";
   %sgfPath = %assetPath @ %assetName @ ".sgf";
   %scriptPath = %assetPath @ %assetName @ ".cs";
   
   %newAsset = new MaterialAsset()
   {
      assetName = %assetName;
      versionId = 1;
      shaderGraph = %sgfPath;
      scriptFile = %assetName @ ".cs";
      originalFilePath = %filePath;
      materialDefinitionName = %assetName;
   };
   
   //check dependencies
   %dependencySlotId = 0;
   for(%i=0; %i < %assetItem.childAssetItems.count(); %i++)
   {
      %childAssetItem = %assetItem.childAssetItems.getKey(%i);
      
      if(!isObject(%childAssetItem) || %childAssetItem.skip || %childAssetItem.processed == false)
         continue;

      %depAssetType = %childAssetItem.assetType;
      if(%depAssetType $= "ImageAsset")
      {
         %matSet = "%newAsset.imageMap"@%dependencySlotId@"=\"@Asset="@%moduleName@":"@%childAssetItem.assetName@"\";";
         eval(%matSet);
         %dependencySlotId++;
      }
   }
   
   %assetImportSuccessful = TamlWrite(%newAsset, %tamlpath);
   
   //if we're set to save a composite image, we do that first
   if(getAssetImportConfigValue("Materials/CreateComposites", "1") == 1)
   {
      //don't save a composite if we've already got one bound
      if(%assetItem.compositeImageAsset !$= "" && %assetItem.compositeImageAsset.generatedAsset)
      {
         if(%assetItem.roughnessImageAsset !$= "" || %assetItem.AOImageAsset !$= "" || %assetItem.metalnessImageAsset !$= "")
         {
            %channelKey = "0 1 2 3";
            
            saveCompositeTexture(%assetItem.AOImageAsset.filePath,
                                 %assetItem.roughnessImageAsset.filePath,
                                 %assetItem.metalnessImageAsset.filePath,"",
                                 %channelKey, 
                                 %assetItem.compositeImageAsset.filePath); 
                                 
            %compositeAssetId = %moduleName @ ":" @ assetItem.compositeImageAsset.assetName;
            AssetDatabase.refreshAsset(%compositeAssetId);
         }
      }
   }
   
   %file = new FileObject();

   if(%file.openForWrite(%scriptPath))
   {
      %file.writeline("//--- OBJECT WRITE BEGIN ---");
      %file.writeline("singleton Material(" @ %assetName @ ") {");
      
      //TODO: pass along the shape's target material for this just to be sure
      %file.writeLine("   mapTo = \"" @ %assetName @ "\";"); 
      
      //now we re-iterate back over our child items so we can map them correctly
      for(%i=0; %i < %assetItem.childAssetItems.count(); %i++)
      {
         %childAssetItem = %assetItem.childAssetItems.getKey(%i);
         
         if(!isObject(%childAssetItem) || %childAssetItem.skip || %childAssetItem.processed == false)
            continue;

         if(%childAssetItem.assetType $= "ImageAsset")
         {
            %mapFieldName = "";
            if(%childAssetItem.imageType $= "Albedo")
               %mapFieldName = "DiffuseMap";
            else if(%childAssetItem.imageType $= "Normal")
               %mapFieldName = "NormalMap";
            else if(%childAssetItem.imageType $= "Metalness")
               %mapFieldName = "MetalMap";
            else if(%childAssetItem.imageType $= "Roughness")
               %mapFieldName = "RoughnessMap";
            else if(%childAssetItem.imageType $= "AO")
               %mapFieldName = "AOMap";
            else if(%childAssetItem.imageType $= "Composite")
               %mapFieldName = "PBRConfigMap";
            
            %path = fileName(%childAssetItem.filePath);
            %file.writeline("   "@ %mapFieldName @ "[0] = \"" @ %path @"\";");
            %file.writeline("   "@ %mapFieldName @ "Asset[0] = \"" @ %moduleName @ ":" @ %childAssetItem.assetName @"\";");
         }
      }
      %file.writeline("};");
      %file.writeline("//--- OBJECT WRITE END ---");
      
      %file.close();
   }
   
   %moduleDef = ModuleDatabase.findModule(%moduleName,1);
         
   if(!AssetBrowser.isAssetReImport)
      AssetDatabase.addDeclaredAsset(%moduleDef, %tamlpath);
   else
      AssetDatabase.refreshAsset(%assetId);
}

function AssetBrowser::buildMaterialAssetPreview(%this, %assetDef, %previewData)
{
   %previewData.assetName = %assetDef.materialDefinitionName;
   %previewData.assetPath = %assetDef.scriptFile;

   //Lotta prepwork
   %previewData.doubleClickCommand = %assetDef@".materialDefinitionName.reload(); "
                                   @ "$Tools::materialEditorList = \"\";"
                                   @ "EWorldEditor.clearSelection();"
                                   @ "MaterialEditorGui.currentObject = 0;"
                                   @ "MaterialEditorGui.currentMode = \"asset\";"
                                   @ "MaterialEditorGui.currentMaterial = "@%assetDef@".materialDefinitionName;"
                                   @ "MaterialEditorGui.setActiveMaterial( "@%assetDef@".materialDefinitionName );"
                                   @ "EditorGui.setEditor(MaterialEditorPlugin); "
                                   @ "AssetBrowser.hideDialog();";
   
   %test = %assetDef.materialDefinitionName.diffuseMapAsset[0];
   
   if(isFile(%assetDef.materialDefinitionName.diffuseMap[0]))
      %previewData.previewImage = %assetDef.materialDefinitionName.diffuseMap[0];
   else if(%assetDef.materialDefinitionName.diffuseMapAsset[0] !$= "")
   {
      %imgAsset = AssetDatabase.acquireAsset(%assetDef.materialDefinitionName.diffuseMapAsset[0]);
      %previewData.previewImage = %imgAsset.getImageFilename();
   }
   else
      %previewData.previewImage = "tools/assetBrowser/art/materialIcon";
   
   %previewData.assetFriendlyName = %assetDef.assetName;
   %previewData.assetDesc = %assetDef.description;
   %previewData.tooltip = "Asset Name: " @ %assetDef.assetName @ "\n" @ 
                           "Asset Type: Material Asset\n" @  
                           "Asset Defition ID: " @  %assetDef;
}

function AssetBrowser::onMaterialAssetEditorDropped(%this, %assetDef, %position)
{
   //echo("DROPPED A SHAPE ON THE EDITOR WINDOW!"); 
   //first, see if we hit a static shape
   %mask = $TypeMasks::StaticObjectType | $TypeMasks::StaticShapeObjectType | $TypeMasks::TerrainObjectType;
   
   %targetPosition = EWorldEditor.unproject(%position SPC 1000);
   %camPos = LocalClientConnection.camera.getPosition();
   %rayResult = materialRayCast(%camPos, %targetPosition, -1, 0, false);
   
   %validTarget = false;
   if(%rayResult != 0)
   {
      %obj = getWord(%rayResult, 0);
      if(%obj.isMemberOfClass("TSStatic"))
      {
         //oh, cool a valid target! 
         %obj.materialSlot0 = %assetDef.getAssetId();
         echo("MaterialSlot0 set to " @ %assetDef.getAssetId());
      }
   }

   EWorldEditor.isDirty = true;
   
}

function GuiInspectorTypeMaterialAssetPtr::onControlDropped( %this, %payload, %position )
{
   Canvas.popDialog(EditorDragAndDropLayer);
   
   // Make sure this is a color swatch drag operation.
   if( !%payload.parentGroup.isInNamespaceHierarchy( "AssetPreviewControlType_AssetDrop" ) )
      return;

   %assetType = %payload.dragSourceControl.parentGroup.assetType;
   %module = %payload.dragSourceControl.parentGroup.moduleName;
   %assetName = %payload.dragSourceControl.parentGroup.assetName;
   
   if(%assetType $= "MaterialAsset")
   {
      echo("DROPPED A MATERIAL ON A MATERIAL ASSET COMPONENT FIELD!");  
      //%assetDef = AssetDatabase.acquireAsset(%module @ ":" @ %assetName);
      
      %this.setMaterialAsset(%module @ ":" @ %assetName);
   }
   
   EWorldEditor.isDirty = true;
}
