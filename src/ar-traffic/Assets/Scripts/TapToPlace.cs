using System.Collections.Generic;
using UnityEngine;
using UnityEngine.XR.ARFoundation;
using UnityEngine.XR.ARSubsystems;

public class TapToPlace : MonoBehaviour
{
    [SerializeField] ARRaycastManager raycastManager;
    [SerializeField] GameObject placePrefab;

    static readonly List<ARRaycastHit> Hits = new();
    GameObject spawned;

    void Awake()
    {
        if (!raycastManager) raycastManager = GetComponent<ARRaycastManager>();
        if (!raycastManager) Debug.LogError("Missing ARRaycastManager on this GameObject.");
        if (!placePrefab) Debug.LogError("Assign a prefab to placePrefab in the Inspector.");
    }

    void Update()
    {
        if (Input.touchCount == 0) return;

        var touch = Input.GetTouch(0);
        if (touch.phase != TouchPhase.Began) return;

        if (raycastManager == null) return;

        if (!raycastManager.Raycast(touch.position, Hits, TrackableType.PlaneWithinPolygon))
            return;

        var pose = Hits[0].pose;

        if (spawned == null)
            spawned = Instantiate(placePrefab, pose.position, pose.rotation);
        else
            spawned.transform.SetPositionAndRotation(pose.position, pose.rotation);
    }
}

