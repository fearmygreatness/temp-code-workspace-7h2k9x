#Requires Autohotkey v2.0+
#SingleInstance Force

#include %A_LineFile%\..\Gif Animation\ImagePut.ahk

global g__daGui := (g := Gui('+AlwaysOnTop -Caption', 'Checklist: '), g.SetFont('s12'), g.Show('Hide w1260 h660'), g)

global ini := FileExist(p := A_ScriptDir "\Checklist.ini") ? p : (FileAppend(Chr(0xEF) Chr(0xBB) Chr(0xBF), p), p)
global sel := IniRead(ini, "Selected", "templet", "Practice Test Patient")

global roomBoxes := []
global roomOccupied := []
global draggableImages := []
global imageGroups := []

; Room definitions map
global roomDefinitions := Map(
    "ExamRoom5", {x: 67, y: 35, w: 124, h: 124, name: "Exam Room 5"},
    "ExamRoom4", {x: 191, y: 35, w: 124, h: 124, name: "Exam Room 4"},
    "ExamRoom3", {x: 315, y: 35, w: 124, h: 124, name: "Exam Room 3"},
    "ExamRoom2", {x: 439, y: 35, w: 124, h: 124, name: "Exam Room 2"},
    "FrontDesk", {x: 563, y: 35, w: 124, h: 124, name: "Front Desk"},
    "Lobby", {x: 687, y: 35, w: 62, h: 124, name: "Lobby"},
    "WaitingArea", {x: 749, y: 35, w: 186, h: 124, name: "Waiting Area"},
    "Glenda", {x: 191, y: 189, w: 62, h: 62, name: "Glenda"},
    "Prov2", {x: 191, y: 251, w: 62, h: 62, name: "Prov 2"},
    "Prov3", {x: 191, y: 313, w: 62, h: 62, name: "Prov 3"},
    "Audio", {x: 811, y: 407, w: 124, h: 124, name: "Audio"}
)

; Patient card definitions map
global patientCards := Map(
    "Patient1", {
        patientName: "Jennifer Montenegro",
        appointmentType: "MPD Applicant Physical", 
        time: "8:30 AM",
        appointmentNumber: "#24"
    },
    "Patient2", {
        patientName: "Michael Johnson",
        appointmentType: "Annual Physical",
        time: "9:15 AM", 
        appointmentNumber: "#25"
    },
    "Patient3", {
        patientName: "Sarah Williams",
        appointmentType: "Follow-up Visit",
        time: "10:00 AM",
        appointmentNumber: "#26"
    },
    "Patient4", {
        patientName: "Robert Davis",
        appointmentType: "Pre-employment Exam",
        time: "10:45 AM",
        appointmentNumber: "#27"
    }
)

global MainTabs := g__daGui.AddTab2("x-100 y-100 w0 h0 -Wrap +Theme vTabControl", ["General", "Advanced", "Language", "Theme", "About", "Schematic"])

IsOnSchematicTab() {
    global MainTabs
    try {
        return (1 = 1)
    } catch {
        return false
    }
}

GuiButtonIcon(Handle, File, Index := 1, Options := '') {
    RegExMatch(Options, 'i)w\K\d+', &W) ? W := W.0 : W := 16
    RegExMatch(Options, 'i)h\K\d+', &H) ? H := H.0 : H := 16
    RegExMatch(Options, 'i)s\K\d+', &S) ? W := H := S.0 : ''
    RegExMatch(Options, 'i)l\K\d+', &L) ? L := L.0 : L := 0
    RegExMatch(Options, 'i)t\K\d+', &T) ? T := T.0 : T := 0
    RegExMatch(Options, 'i)r\K\d+', &R) ? R := R.0 : R := 0
    RegExMatch(Options, 'i)b\K\d+', &B) ? B := B.0 : B := 0
    RegExMatch(Options, 'i)a\K\d+', &A) ? A := A.0 : A := 0
    W *= A_ScreenDPI / 96, H *= A_ScreenDPI / 96
    button_il := Buffer(20 + A_PtrSize)
    normal_il := DllCall("ImageList_Create", "Int", W, "Int", H, "UInt", 0x21, "Int", 1, "Int", 1)
    NumPut("Ptr", normal_il, button_il, 0)
    NumPut("UInt", L, button_il, 0 + A_PtrSize)
    NumPut("UInt", T, button_il, 4 + A_PtrSize)
    NumPut("UInt", R, button_il, 8 + A_PtrSize)
    NumPut("UInt", B, button_il, 12 + A_PtrSize)
    NumPut("UInt", A, button_il, 16 + A_PtrSize)
    SendMessage(5634, 0, button_il, Handle)
    return IL_Add(normal_il, File, Index)
}

GuiMove(A_GuiEvent := "", GuiCtrlObj := "", Info := "", *) {
    PostMessage(0xA1, 2)
    Return
}

IsPointInRect(pointX, pointY, rectX, rectY, rectW, rectH) {
    return (pointX >= rectX && pointX <= rectX + rectW && pointY >= rectY && pointY <= rectY + rectH)
}

; Function to check if an object is a patient card
IsPatientCard(imageObj) {
    return imageObj.HasOwnProp("patientKey")
}

; Function to generate patient card text from patient data
GeneratePatientCardText(patientKey, roomName := "") {
    global patientCards
    
    if (!patientCards.Has(patientKey)) {
        return "Unknown Patient"
    }
    
    patient := patientCards[patientKey]
    baseText := patient.patientName . "`n" . patient.appointmentType . "`n" . patient.time . "            " . patient.appointmentNumber
    
    if (roomName != "") {
        return baseText . "`n" . roomName
    }
    return baseText
}

; Function to update patient card display text
UpdatePatientCardDisplay(patientCard, roomIndex := 0) {
    global roomBoxes, patientCards
    
    if (!IsPatientCard(patientCard)) {
        return
    }
    
    roomName := ""
    if (roomIndex > 0 && roomIndex <= roomBoxes.Length) {
        roomName := roomBoxes[roomIndex].name
    }
    
    newText := GeneratePatientCardText(patientCard.patientKey, roomName)
    patientCard.Text := newText
}

FindClosestGridPosition(roomIndex, mouseX, mouseY, imageWidth := 60, imageHeight := 60, gridSize := 1) {
    room := roomBoxes[roomIndex]
    padding := 1
    
    if (gridSize = 4) {
        if (room.w < 122 || room.h < 60) {
            return {pos: false, existingImg: false}
        }
        x := room.x + padding
        y := room.y + padding
        
        conflictingImages := []
        for img in roomOccupied[roomIndex] {
            conflictingImages.Push(img)
        }
        
        return {pos: {x: x, y: y}, existingImg: conflictingImages.Length > 0 ? conflictingImages : false}
    }
    
    imagesPerRow := Max(1, Round(room.w / 62))
    imagesPerCol := Max(1, Round(room.h / 62))
    cellWidth := 62
    cellHeight := 62
    relX := mouseX - room.x - padding
    relY := mouseY - room.y - padding
    col := Floor(relX / cellWidth)
    row := Floor(relY / cellHeight)
    
    col := Min(Max(col, 0), imagesPerRow - 1)
    row := Min(Max(row, 0), imagesPerCol - 1)
    
    x := room.x + padding + col * 62
    y := room.y + padding + row * 62
    
    for img in roomOccupied[roomIndex] {
        img.GetPos(&imgX, &imgY)
        if (Abs(imgX - x) < 5 && Abs(imgY - y) < 5) {
            return {pos: {x: x, y: y}, existingImg: img}
        }
    }
    return {pos: {x: x, y: y}, existingImg: false}
}

RemoveOverlappingItems(roomIndex, newX, newY, newW, newH) {
    global roomOccupied
    
    if (roomIndex <= 0 || roomIndex > roomOccupied.Length) {
        return
    }
    
    itemsToRemove := []
    
    for existingImg in roomOccupied[roomIndex] {
        existingImg.GetPos(&existingX, &existingY)
        
        existingW := 60
        existingH := 60
        
        if (IsPatientCard(existingImg)) {
            existingW := 122
            existingH := 60
        }
        
        if (RectanglesOverlap(newX, newY, newW, newH, existingX, existingY, existingW, existingH)) {
            itemsToRemove.Push(existingImg)
        }
    }
    
    for item in itemsToRemove {
        RemoveImageFromRoom(item)
        fallbackPos := FindFallbackPosition(item)
        item.Move(fallbackPos.x, fallbackPos.y)
        item.Redraw()
    }
}

RectanglesOverlap(x1, y1, w1, h1, x2, y2, w2, h2) {
    overlapX := (x1 < x2 + w2) && (x2 < x1 + w1)
    overlapY := (y1 < y2 + h2) && (y2 < y1 + h1)
    return overlapX && overlapY
}

CanGroupFitInRoom(dragGroup, roomIndex, currentImage, mouseX, mouseY, isCurrentImageText) {
    global roomBoxes
    
    if (dragGroup.Length <= 1) {
        return true
    }
    
    room := roomBoxes[roomIndex]
    
    if (isCurrentImageText || dragGroup.Length > 1) {
        hasTextInGroup := false
        for img in dragGroup {
            if (IsPatientCard(img)) {
                hasTextInGroup := true
                break
            }
        }
        
        if (hasTextInGroup) {
            if (room.w < 122 || room.h < 60) {
                return false
            }
            return true
        }
    }
    
    if (!isCurrentImageText) {
        imagesPerRow := Max(1, Round(room.w / 62))
        imagesPerCol := Max(1, Round(room.h / 62))
        totalAvailablePositions := imagesPerRow * imagesPerCol
        
        minWidth := Min(dragGroup.Length, imagesPerRow) * 62
        minHeight := Ceil(dragGroup.Length / imagesPerRow) * 62
        
        if (room.w >= minWidth && room.h >= minHeight) {
            return true
        }
    }
    
    return true
}

Range(start, end) {
    result := []
    loop end - start + 1 {
        result.Push(start + A_Index - 1)
    }
    return result
}

ShowImageName(imageObj, *) {
    imageName := GetImageName(imageObj)
    MsgBox(imageName, "Image Information", 0x40000)
}

FindFallbackPosition(imageObj) {
    if (imageObj.HasOwnProp("imageData")) {
        return {x: imageObj.imageData.x, y: imageObj.imageData.y}
    }
    
    baseX := 1000
    baseY := 50
    imageWidth := 60
    imageHeight := 60
    imageIndex := 0
    
    for i, img in draggableImages {
        if (img == imageObj) {
            imageIndex := i
            break
        }
    }
    
    if (imageIndex = 11) {
        return {x: 1080, y: 500}
    }
    
    row := Floor((imageIndex - 1) / 2)
    col := Mod(imageIndex - 1, 2)
    x := baseX + col * (imageWidth + 10)
    y := baseY + row * (imageHeight + 10)
    return {x: x, y: y}
}

RightClickImage(imageObj, *) {
    SeparateFromGroup(imageObj)
    RemoveImageFromRoom(imageObj)
    fallbackPos := FindFallbackPosition(imageObj)
    imageObj.Move(fallbackPos.x, fallbackPos.y)
    imageObj.Redraw()
    g__daGui.Show("w1260 h660")
}

GetImageName(imageObj) {
    if (imageObj.HasOwnProp("imageData") && imageObj.imageData.HasOwnProp("name")) {
        return imageObj.imageData.name
    }
    return "Unknown Image"
}

RemoveImageFromRoom(imageObj) {
    global textCurrentRoom
    
    for roomIndex, imageList in roomOccupied {
        for i, img in imageList {
            if (img == imageObj) {
                imageList.RemoveAt(i)
                
                if (IsPatientCard(img)) {
    			UpdatePatientCardDisplay(img, 0)
		}
                
                return roomIndex
            }
        }
    }
    return 0
}

FindImageGroup(imageObj) {
    global imageGroups
    for i, group in imageGroups {
        for img in group {
            if (img == imageObj) {
                return i
            }
        }
    }
    return 0
}

UpdateGroups(roomIndex) {
    global roomOccupied, imageGroups
    
    if (roomIndex <= 0 || roomOccupied[roomIndex].Length < 2) {
        return
    }
    
    roomImages := roomOccupied[roomIndex]
    
    hasPatientCard := false
    patientCardElement := ""
    for img in roomImages {
        if (IsPatientCard(img)) {
            hasPatientCard := true
            patientCardElement := img
            break
        }
    }
    
    if (!hasPatientCard) {
        return
    }
    
    patientCardElement.GetPos(&textX, &textY)
    
    groupableImages := [patientCardElement]
    
    for img in roomImages {
        if (img != patientCardElement) {
            img.GetPos(&imgX, &imgY)
            
            if (imgY > textY && Abs(imgX - textX) <= 70) {
                groupableImages.Push(img)
            }
        }
    }
    
    for img in roomImages {
        groupIndex := FindImageGroup(img)
        if (groupIndex > 0) {
            for i, groupImg in imageGroups[groupIndex] {
                if (groupImg == img) {
                    imageGroups[groupIndex].RemoveAt(i)
                    break
                }
            }
            if (imageGroups[groupIndex].Length = 0) {
                imageGroups.RemoveAt(groupIndex)
            }
        }
    }
    
    ; Create new group only if we have patient card + at least one image below it
	if (groupableImages.Length > 1) {
   	 imageGroups.Push(groupableImages)
  	 
	}
}

SeparateFromGroup(imageObj) {
    global imageGroups
    
    groupIndex := FindImageGroup(imageObj)
    if (groupIndex > 0) {
        if (IsPatientCard(imageObj)) {
            for img in imageGroups[groupIndex] {
                if (!IsPatientCard(img)) {
                    RemoveImageFromRoom(img)
                    fallbackPos := FindFallbackPosition(img)
                    img.Move(fallbackPos.x, fallbackPos.y)
                    img.Redraw()
                }
            }
            imageGroups.RemoveAt(groupIndex)
        } else {
            for i, groupImg in imageGroups[groupIndex] {
                if (groupImg == imageObj) {
                    imageGroups[groupIndex].RemoveAt(i)
                    break
                }
            }
            if (imageGroups[groupIndex].Length = 0) {
                imageGroups.RemoveAt(groupIndex)
            }
        }
        return true
    }
    return false
}

UpdateTextDisplay(roomIndex := 0) {
    ; Legacy function - no longer needed since all patient cards are updated individually
    ; Kept for backward compatibility but does nothing
    return
}

g__daGui.OnEvent("Close", (*) => HandleGuiCloseOrEscape())

CloseGuiBtn := g__daGui.Add("Text", "x1220 y3 w35 h30 +Border +Center +0x200 +Background0xF0F0F0 cRed", "✕")
CloseGuiBtn.SetFont("s24 Bold")
CloseGuiBtn.OnEvent("Click", HandleCloseClick)

draggableSection1 := g__daGui.Add("Text", "x2 y2 w802 h30 Background87CEEB Center 0x200 vDraggable1", "Practice Test Patient")
draggableSection1.OnEvent("Click", GuiMove.Bind("Normal"))

draggableSection2 := g__daGui.Add("Text", "x1120 y2 w95 h30 Background87CEEB Center 0x200 vDraggable2", "")
draggableSection2.OnEvent("Click", GuiMove.Bind("Normal"))

draggableSection3 := g__daGui.Add("Text", "x1065 y628 w193 h30 Background87CEEB Center 0x200 vDraggable3", "")
draggableSection3.OnEvent("Click", GuiMove.Bind("Normal"))

g__daGui.AddText("x1225 y615", Chr(118) . Chr(49) . Chr(46) . Chr(48))

CreateRoom(x, y, w, h, text, bgColor := "0xFFFFFF", textColor := "0x000000") {
    roomIndex := roomBoxes.Length + 1
    roomBoxes.Push({x: x, y: y, w: w, h: h, name: text, index: roomIndex})
    roomOccupied.Push([])
    room := g__daGui.Add("Progress", "x" x " y" y " w" w " h" h " Background" bgColor " c" bgColor " Range0-100 Disabled", 100)
    g__daGui.Add("Progress", "x" x " y" y " w" w " h1 Background0x000000 c0x000000 Range0-100 Disabled", 100)
    g__daGui.Add("Progress", "x" x " y" (y+h-1) " w" w " h1 Background0x000000 c0x000000 Range0-100 Disabled", 100)
    g__daGui.Add("Progress", "x" x " y" y " w1 h" h " Background0x000000 c0x000000 Range0-100 Disabled", 100)
    g__daGui.Add("Progress", "x" (x+w-1) " y" y " w1 h" h " Background0x000000 c0x000000 Range0-100 Disabled", 100)
    textX := x + 5
    textY := y + (h / 2) - 8
    textW := w - 10
    g__daGui.SetFont("s9", "Arial")
    if (StrLen(text) > 20) {
        g__daGui.SetFont("s8", "Arial")
    }
    if (StrLen(text) > 30) {
        g__daGui.SetFont("s7", "Arial")
    }
    textCtrl := g__daGui.Add("Text", "x" textX " y" textY " w" textW " h20 BackgroundTrans c" textColor " Disabled", text)
    return {room: room, text: textCtrl}
}

for roomKey, roomData in roomDefinitions {
    CreateRoom(roomData.x, roomData.y, roomData.w, roomData.h, roomData.name)
}

global imageBasePath := "\\pfc-ctx1\redirecteduserfolders\ZZ Custom ProjectsV2\AHK Script Projects\090 - PFC Checklist\Tab Images\"

global imageDefinitions := Map(
    "DrStubbs", {type: "Picture", x: 1080, y: 150, w: 60, h: 60, imageFile: "box01.png", name: "Dr. Stubbs Schedule", fallbackIndex: 1},
    "Courtney", {type: "Picture", x: 1150, y: 150, w: 60, h: 60, imageFile: "box02.png", name: "Courtney", fallbackIndex: 2},
    "DrB", {type: "Picture", x: 1080, y: 220, w: 60, h: 60, imageFile: "box03.png", name: "Dr. B Schedule", fallbackIndex: 3},
    "DrMalomo", {type: "Picture", x: 1150, y: 220, w: 60, h: 60, imageFile: "box04.png", name: "Dr. Malomo Schedule", fallbackIndex: 4},
    "Glenda", {type: "Picture", x: 1080, y: 290, w: 60, h: 60, imageFile: "box05.png", name: "Glenda", fallbackIndex: 5},
    "Image6", {type: "Picture", x: 1150, y: 290, w: 60, h: 60, imageFile: "box06.png", name: "Image 6", fallbackIndex: 6},
    "Image7", {type: "Picture", x: 1080, y: 360, w: 60, h: 60, imageFile: "box07.png", name: "Image 7", fallbackIndex: 7},
    "Patient1", {type: "PatientCard", x: 1080, y: 500, w: 122, h: 60, patientKey: "Patient1", options: "+Border +Left Background0xE6E6FA c0x000080", fontSize: "s8", fontName: "Arial", fallbackIndex: 11},
    "Patient2", {type: "PatientCard", x: 1080, y: 570, w: 122, h: 60, patientKey: "Patient2", options: "+Border +Left Background0xFFE4E1 c0x8B0000", fontSize: "s8", fontName: "Arial", fallbackIndex: 12},
    "Patient3", {type: "PatientCard", x: 1150, y: 500, w: 122, h: 60, patientKey: "Patient3", options: "+Border +Left Background0xF0FFF0 c0x006400", fontSize: "s8", fontName: "Arial", fallbackIndex: 13},
    "Patient4", {type: "PatientCard", x: 1150, y: 570, w: 122, h: 60, patientKey: "Patient4", options: "+Border +Left Background0xFFFACD c0x8B4513", fontSize: "s8", fontName: "Arial", fallbackIndex: 14}
)

global draggableImages := []
global patientCardObjects := []

for imageKey, imageData in imageDefinitions {
    if (imageData.type = "Picture") {
        fullImagePath := imageBasePath . imageData.imageFile
        imageObj := g__daGui.Add("Picture", "x" imageData.x " y" imageData.y " w" imageData.w " h" imageData.h " BackgroundTrans", fullImagePath)
    } else if (imageData.type = "PatientCard") {
        cardText := GeneratePatientCardText(imageData.patientKey)
        imageObj := g__daGui.Add("Text", "x" imageData.x " y" imageData.y " w" imageData.w " h" imageData.h " " imageData.options, cardText)
        if (imageData.HasOwnProp("fontSize") && imageData.HasOwnProp("fontName")) {
            imageObj.SetFont(imageData.fontSize, imageData.fontName)
        }
        imageObj.patientKey := imageData.patientKey
        patientCardObjects.Push(imageObj)
    }
    
    imageObj.imageKey := imageKey
    imageObj.imageData := imageData
    
    imageObj.OnEvent("Click", StartDrag.Bind(imageObj))
    imageObj.OnEvent("ContextMenu", RightClickImage.Bind(imageObj))
    imageObj.OnEvent("DoubleClick", ShowImageName.Bind(imageObj))
    
    draggableImages.Push(imageObj)
}

global draggableText := ""
global allPatientCards := []

for img in draggableImages {
    if (img.HasOwnProp("patientKey")) {
        allPatientCards.Push(img)
        if (draggableText == "") {
            draggableText := img
        }
    }
}

global textCurrentRoom := 0

StartDrag(currentImage, *) {
    global imageGroups
    
    groupIndex := FindImageGroup(currentImage)
    dragGroup := groupIndex > 0 ? imageGroups[groupIndex] : [currentImage]
    
    hasPatientCard := false
    for img in dragGroup {
        if (IsPatientCard(img)) {
            hasPatientCard := true
            break
        }
    }
    
    originalPositions := []
    for img in dragGroup {
    img.GetPos(&origX, &origY)
    originalPositions.Push({img: img, x: origX, y: origY})
    ; Store current room index before removing
    currentRoom := 0
    for roomIndex, imageList in roomOccupied {
        for roomImg in imageList {
            if (roomImg == img) {
                currentRoom := roomIndex
                break
            }
        }
        if (currentRoom > 0) {
            break
        }
    }
    RemoveImageFromRoom(img)
    ; Restore display with room name during drag
    if (IsPatientCard(img) && currentRoom > 0) {
        UpdatePatientCardDisplay(img, currentRoom)
    }
	}
    
    MouseGetPos(&mouseX, &mouseY)
    currentImage.GetPos(&picX, &picY)
    offsetX := mouseX - picX
    offsetY := mouseY - picY
    
    static lastX := 0, lastY := 0
    SetTimer(DragPicture, 16)
    
    DragPicture() {
        if (!GetKeyState("LButton", "P")) {
            SetTimer(DragPicture, 0)
            MouseGetPos(&finalX, &finalY)
            finalPicX := finalX - offsetX
            finalPicY := finalY - offsetY
            picCenterX := finalPicX + 30
            picCenterY := finalPicY + 30
            snapped := false
            
            isCurrentImagePatientCard := IsPatientCard(currentImage)
            
            i := roomBoxes.Length
            while (i >= 1) {
                room := roomBoxes[i]
                if (IsPointInRect(picCenterX, picCenterY, room.x, room.y, room.w, room.h)) {
                    canGroupFit := CanGroupFitInRoom(dragGroup, i, currentImage, finalX, finalY, isCurrentImagePatientCard)
                    
                    if (canGroupFit) {
                       if (hasPatientCard) {
   			 result := FindClosestGridPosition(i, finalX, finalY, 122, 60, 4)
				} else {
  				  result := FindClosestGridPosition(i, finalX, finalY, 60, 60, 1)
				}
                    } else {
                        result := {pos: false, existingImg: false}
                    }
                    
                    if (result.pos) {
                        if (result.existingImg) {
                            if (Type(result.existingImg) = "Array") {
                                for conflictImg in result.existingImg {
                                    shouldDisplace := false
                                    
                                    if (hasPatientCard) {
                                        if (IsPatientCard(conflictImg)) {
                                            shouldDisplace := true
                                        } else {
                                            conflictGroupIndex := FindImageGroup(conflictImg)
                                            if (conflictGroupIndex > 0) {
                                                for groupImg in imageGroups[conflictGroupIndex] {
                                                    if (IsPatientCard(groupImg)) {
                                                        shouldDisplace := true
                                                        break
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        shouldDisplace := true
                                    }
                                    
                                    if (shouldDisplace) {
  				 	 ; First separate from group if part of one
  						  SeparateFromGroup(conflictImg)
   						 RemoveImageFromRoom(conflictImg)
  						  fallbackPos := FindFallbackPosition(conflictImg)
    						conflictImg.Move(fallbackPos.x, fallbackPos.y)
 					   conflictImg.Redraw()
						}
                                }
                            } else {
                                shouldDisplace := false
                                
                                if (hasPatientCard) {
                                    if (IsPatientCard(result.existingImg)) {
                                        shouldDisplace := true
                                    } else {
                                        conflictGroupIndex := FindImageGroup(result.existingImg)
                                        if (conflictGroupIndex > 0) {
                                            for groupImg in imageGroups[conflictGroupIndex] {
                                                if (IsPatientCard(groupImg)) {
                                                    shouldDisplace := true
                                                    break
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    shouldDisplace := true
                                }
                                
                                if (shouldDisplace) {
                                    RemoveImageFromRoom(result.existingImg)
                                    fallbackPos := FindFallbackPosition(result.existingImg)
                                    result.existingImg.Move(fallbackPos.x, fallbackPos.y)
                                    result.existingImg.Redraw()
                                }
                            }
                        }
                        
                        if (hasPatientCard) {
                            patientCardElement := ""
                            for img in dragGroup {
                                if (IsPatientCard(img)) {
                                    patientCardElement := img
                                    break
                                }
                            }
                            
                            textX := result.pos.x
                            textY := result.pos.y
                            
                            RemoveOverlappingItems(i, textX, textY, 122, 60)
                           
                           patientCardElement.Move(textX, textY)
                           roomOccupied[i].Push(patientCardElement)
                           
                           for img in dragGroup {
                               if (img != patientCardElement) {
                                   textOrigX := 0
                                   textOrigY := 0
                                   imgOrigX := 0
                                   imgOrigY := 0
                                   
                                   for origPos in originalPositions {
                                       if (origPos.img == patientCardElement) {
                                           textOrigX := origPos.x
                                           textOrigY := origPos.y
                                       }
                                       if (origPos.img == img) {
                                           imgOrigX := origPos.x
                                           imgOrigY := origPos.y
                                       }
                                   }
                                   
                                   offsetX_group := imgOrigX - textOrigX
                                   offsetY_group := imgOrigY - textOrigY
                                   
                                   newX := textX + offsetX_group
                                   newY := textY + offsetY_group
                                   
                                   RemoveOverlappingItems(i, newX, newY, 60, 60)
                                   
                                   img.Move(newX, newY)
                                   roomOccupied[i].Push(img)
                               }
                           }
                       } else {
                           currentImage.Move(result.pos.x, result.pos.y)
                           roomOccupied[i].Push(currentImage)
                           
                           currentImage.GetPos(&mainX, &mainY)
                           for j, img in dragGroup {
                               if (img != currentImage) {
                                   for origPos in originalPositions {
                                       if (origPos.img == img) {
                                           for mainOrigPos in originalPositions {
                                               if (mainOrigPos.img == currentImage) {
                                                   offsetX_group := origPos.x - mainOrigPos.x
                                                   offsetY_group := origPos.y - mainOrigPos.y
                                                   newX := mainX + offsetX_group
                                                   newY := mainY + offsetY_group
                                                   
                                                   conflictingImg := ""
                                                   for existingImg in roomOccupied[i] {
                                                       if (existingImg != currentImage) {
                                                           existingImg.GetPos(&existingX, &existingY)
                                                           if (Abs(existingX - newX) < 10 && Abs(existingY - newY) < 10) {
                                                               conflictingImg := existingImg
                                                               break
                                                           }
                                                       }
                                                   }
                                                   
                                                   if (conflictingImg != "") {
                                                       RemoveImageFromRoom(conflictingImg)
                                                       fallbackPos := FindFallbackPosition(conflictingImg)
                                                       conflictingImg.Move(fallbackPos.x, fallbackPos.y)
                                                       conflictingImg.Redraw()
                                                   }
                                                   
                                                   img.Move(newX, newY)
                                                   roomOccupied[i].Push(img)
                                                   break
                                               }
                                           }
                                           break
                                       }
                                   }
                               }
                           }
                       }
                       
			; Update patient card displays immediately after placement
			for img in dragGroup {
 			   if (IsPatientCard(img)) {
   			     UpdatePatientCardDisplay(img, i)
   			 }
			}

                       UpdateGroups(i)
			; Update patient card displays after grouping is complete
			for img in dragGroup {
  			  if (IsPatientCard(img)) {
   			     UpdatePatientCardDisplay(img, i)
   			 }
			}
                                              
                       snapped := true
                   }
                   break
               }
               i--
           }
           
           if (!snapped) {
               for j, img in dragGroup {
                   if (img == currentImage) {
                       img.Move(finalPicX, finalPicY)
                   } else {
                       for origPos in originalPositions {
                           if (origPos.img == img) {
                               for mainOrigPos in originalPositions {
                                   if (mainOrigPos.img == currentImage) {
                                       offsetX_group := origPos.x - mainOrigPos.x
                                       offsetY_group := origPos.y - mainOrigPos.y
                                       img.Move(finalPicX + offsetX_group, finalPicY + offsetY_group)
                                       break
                                   }
                               }
                               break
                           }
                       }
                   }
               }
               
               if (hasPatientCard) {
                   for img in dragGroup {
                       if (IsPatientCard(img)) {
                           UpdatePatientCardDisplay(img, 0)
                       }
                   }
                   UpdateTextDisplay(0)
               }
           }
           
           for i, img in dragGroup {
               img.Redraw()
               if (dragGroup.Length > 1 && i < dragGroup.Length) {
                   Sleep(1)
               }
           }
           g__daGui.Show("w1260 h660")
           return
       }
       
       MouseGetPos(&newX, &newY)
       newPicX := newX - offsetX
       newPicY := newY - offsetY
       if (newPicX != lastX || newPicY != lastY) {
           for j, img in dragGroup {
               if (img == currentImage) {
                   img.Move(newPicX, newPicY)
               } else {
                   for origPos in originalPositions {
                       if (origPos.img == img) {
                           for mainOrigPos in originalPositions {
                               if (mainOrigPos.img == currentImage) {
                                   offsetX_group := origPos.x - mainOrigPos.x
                                   offsetY_group := origPos.y - mainOrigPos.y
                                   img.Move(newPicX + offsetX_group, newPicY + offsetY_group)
                                   break
                               }
                           }
                           break
                       }
                   }
               }
           }
           lastX := newPicX
           lastY := newPicY
           static redrawCounter := 0
           redrawCounter++
           if (Mod(redrawCounter, 3) = 0) {
               for img in dragGroup {
                   img.Redraw()
               }
           }
       }
   }
}

HandleCloseClick(*) {
   CloseGuiBtn.Opt("+BackgroundSilver")
   CloseGuiBtn.Redraw()
   Sleep(100)
   HandleGuiCloseOrEscape()
}

Esc::HandleGuiCloseOrEscape()

HandleGuiCloseOrEscape(*) {
   ExitApp()
}

g__daGui.Show()