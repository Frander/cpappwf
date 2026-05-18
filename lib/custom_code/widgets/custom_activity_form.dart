// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
// Imports other custom widgets
// Imports custom actions
// Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

class CustomActivityForm extends StatefulWidget {
  const CustomActivityForm({
    super.key,
    this.width,
    this.height,
    required this.jsonData,
  });

  final double? width;
  final double? height;
  final dynamic jsonData;

  @override
  State<CustomActivityForm> createState() => _CustomActivityFormState();
}

class _CustomActivityFormState extends State<CustomActivityForm> {
  late Activity activity;
  late List<ActivityStep> rootSteps;
  late List<ActivityStep> currentSteps;
  final Set<String> completedSteps = {};

  @override
  void initState() {
    super.initState();
    activity = Activity.fromMap(widget.jsonData as Map<String, dynamic>);
    rootSteps = activity.steps;
    currentSteps = rootSteps;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      constraints: const BoxConstraints.expand(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            activity.name,
            style: FlutterFlowTheme.of(context)
                .displaySmall
                .override(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: currentSteps.isEmpty
                ? _buildCompletion()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: currentSteps.map(_buildStepSection).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSection(ActivityStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    step.nameStep,
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (completedSteps.contains(step.id))
                  const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
          ),
          // Status list
          ...step.statuses.map((status) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Transform.scale(
                scale: 1.3,
                child: RadioListTile<ActivityStatus>(
                  title: Text(
                    status.name,
                    style: FlutterFlowTheme.of(context)
                        .bodyMedium
                        .override(fontSize: 18),
                  ),
                  value: status,
                  // ignore: deprecated_member_use
                  groupValue: null,
                  // ignore: deprecated_member_use
                  onChanged: (_) => _onStatusSelected(step, status),
                  fillColor: WidgetStateProperty.resolveWith<Color>((_) => FlutterFlowTheme.of(context).primary),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),
            );
          }),
          const Divider(thickness: 1.5),
        ],
      ),
    );
  }

  Widget _buildCompletion() {
    bool allDone = completedSteps.length == rootSteps.length;
    if (!allDone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          currentSteps =
              rootSteps.where((s) => !completedSteps.contains(s.id)).toList();
        });
      });
      return Center(
        child: Text(
          'Regresando a pasos pendientes...',
          style: FlutterFlowTheme.of(context).bodyMedium.override(fontSize: 16),
        ),
      );
    }
    return Center(
      child: Text(
        'Proceso completado',
        style: FlutterFlowTheme.of(context).bodyMedium.override(fontSize: 16),
      ),
    );
  }

  void _onStatusSelected(ActivityStep step, ActivityStatus status) {
    setState(() {
      if (status.children.isNotEmpty) {
        // Drill into children steps
        currentSteps = status.children;
      } else {
        // Mark step complete and clear current
        completedSteps.add(step.id);
        currentSteps = [];
      }
    });
  }
}

/// MODELOS PARA PARSEAR EL JSON
class Activity {
  final String name;
  final List<ActivityStep> steps;
  Activity({required this.name, required this.steps});
  factory Activity.fromMap(Map<String, dynamic> m) => Activity(
        name: m['name_activity'] as String,
        steps: (m['activity_steps'] as List<dynamic>)
            .map((e) => ActivityStep.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class ActivityStep {
  final String id;
  final String nameStep;
  final List<ActivityStatus> statuses;
  ActivityStep(
      {required this.id, required this.nameStep, required this.statuses});
  factory ActivityStep.fromMap(Map<String, dynamic> m) => ActivityStep(
        id: m['id_activity_step'].toString(),
        nameStep: m['name_step'] as String,
        statuses: (m['activities_status'] as List<dynamic>)
            .map((e) => ActivityStatus.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

class ActivityStatus {
  final String name;
  final List<ActivityStep> children;
  ActivityStatus({required this.name, required this.children});
  factory ActivityStatus.fromMap(Map<String, dynamic> m) => ActivityStatus(
        name: m['status_name'] as String,
        children: (m['activities_steps_childs'] as List<dynamic>)
            .map((e) => ActivityStep.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
