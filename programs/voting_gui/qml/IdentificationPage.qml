import QtQuick 2.3
import QtQuick.Layouts 1.1
import QtQuick.Controls 1.2
import QtMultimedia 5.0

TaskPage {
   id: container
   nextButtonHighlighted: mayProceed()

   property string imageDir
   //Disabling the camera blocks the UI thread for about a tenth of a second. Unacceptable.
   property bool enableCamera: true //Stack.status === Stack.Activating || Stack.status === Stack.Active

   onBackClicked: window.previousPage()
   onNextClicked: {
      if( mayProceed() ) {
         window.nextPage()
      } else {
         cannotProceedAlert()
      }
   }

   function mayProceed() {
      return true
      for( var i = 0; i < photoButtonRow.children.length; i++ ) {
         var button = photoButtonRow.children[i]
         if( !button.imageAccepted ) {
            return false
         }
      }
      return true
   }
   function cannotProceedAlert() {
      for( var i = 0; i < photoButtonRow.children.length; i++ ) {
         var button = photoButtonRow.children[i]
         if( !button.imageAccepted ) {
            button.errorAlert()
         }
      }
   }

   Component.onCompleted: {
      imageDir = utilities.make_temporary_directory()
      console.log("Image directory: " + imageDir)
      if( bitshares.initialized )
         bitshares.create_voter_account()
      else
         bitshares.initialization_complete.connect(bitshares.create_voter_account)
   }

   QtObject {
      id: d
      readonly property ViewFinder snapper: photoSnapper.createObject(container, {"visible": false,
                                                                                  "camera": camera})
      property PhotoButton currentButton

      function startSnapshot(button, overlaySource) {
         d.currentButton = button
         snapper.owner = button
         snapper.state = "COLLAPSED"
         if( button.imageSet ) {
            snapper.oldImage = button.currentImage
         } else {
            snapper.oldImage = ""
         }
         snapper.visible = true

         if( typeof overlaySource !== "undefined" ) {
            d.snapper.viewFinderOverlaySource = overlaySource
         } else {
            d.snapper.viewFinderOverlaySource = ""
         }

         d.snapper.state = "EXPANDED"
      }
   }
   Component {
      id: photoSnapper

      ViewFinder {
         viaItem: overlord
         expandedContainer: container
         onExpanding: {
            if( d.currentButton.imageSet )
            {
               previewSource = d.currentButton.currentImage
               hasImage = true
            }
         }
         onCollapsed: {
            if( hasImage ) {
               d.currentButton.currentImage = "file:" + camera.imageCapture.capturedImagePath
               d.currentButton.acceptImage()
            }
            d.currentButton = null
            d.snapper.visible = false
         }
         onCaptureRequested: camera.imageCapture.captureToLocation(imageDir)
      }
   }
   Item {
      id: overlord
      //This item exists to be the via property of the ParentAnimation of the ViewFinder as it collapses.
      //Without it, the ViewFinder sinks below the camera buttons while collapsing.
      z: d.snapper.greyer.z + 1
   }
   Camera {
      id: camera
      cameraState: enableCamera? Camera.ActiveState : Camera.LoadedState
      onError: console.log("Camera error: " + errorString)
      imageCapture {
         onImageCaptured: {
            camera.captureMode = Camera.CaptureViewfinder
            d.snapper.previewSource = preview
            d.snapper.state = "CAPTURED"
         }
      }
   }

   RowLayout {
      id: photoButtonRow
      anchors {
         left: parent.left
         right: parent.right
         verticalCenter: parent.verticalCenter
         verticalCenterOffset: -height / 3
      }
      height: width / 5 + spacing * 2;

      PhotoButton {
         id: userPhotoButton
         Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
         Layout.fillHeight: true
         onClicked: d.startSnapshot(this, "qrc:/res/person_silhouette.png")
         labelText: qsTr("Your Photo")
         onCurrentImageChanged: window.userPhoto = currentImage
         imageAccepted: window.userPhotoAccepted

         function acceptImage() {
            window.userPhotoAccepted = true
         }
      }
      PhotoButton {
         id: idFrontPhotoButton
         Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
         Layout.fillHeight: true
         onClicked: d.startSnapshot(this, "qrc:/res/id_front.png")
         labelText: qsTr("ID Card Front")
         onCurrentImageChanged: window.idFrontPhoto = currentImage
         imageAccepted: window.idFrontPhotoAccepted

         function acceptImage() {
            window.idFrontPhotoAccepted = true
         }
      }
      PhotoButton {
         id: idBackPhotoButton
         Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
         Layout.fillHeight: true
         onClicked: d.startSnapshot(this, "qrc:/res/id_back.png")
         labelText: qsTr("ID Card Back")
         onCurrentImageChanged: window.idBackPhoto = currentImage
         imageAccepted: window.idBackPhotoAccepted

         function acceptImage() {
            window.idBackPhotoAccepted = true
         }
      }
   }
   Text {
      anchors.top: photoButtonRow.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width * .9
      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
      color: "red"
      font.pointSize: window.height * .02
      visible: window.rejectionReason
      text: "Your identity has been rejected. Please retake any photos which are no longer checkmarked and try " +
            "again.\nVerifier comment: " + window.rejectionReason
   }
}
