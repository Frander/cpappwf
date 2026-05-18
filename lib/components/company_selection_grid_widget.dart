import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'company_selection_grid_model.dart';
export 'company_selection_grid_model.dart';

class CompanySelectionGridWidget extends StatefulWidget {
  const CompanySelectionGridWidget({
    super.key,
    required this.onCompanySelected,
  });

  final Future Function(CompaniesStruct company) onCompanySelected;

  @override
  State<CompanySelectionGridWidget> createState() =>
      _CompanySelectionGridWidgetState();
}

class _CompanySelectionGridWidgetState
    extends State<CompanySelectionGridWidget> {
  late CompanySelectionGridModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CompanySelectionGridModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();

    // Cargar empresas al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCompanies());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    setState(() {
      _model.isLoading = true;
    });

    try {
      _model.apiResultCompanies =
          await APIClickPalmGroup.companiesGETCall.call();

      if ((_model.apiResultCompanies?.succeeded ?? false)) {
        setState(() {
          _model.companiesList = getJsonField(
            (_model.apiResultCompanies?.jsonBody ?? ''),
            r'''$''',
            true,
          )!
              .toList();
          _model.filteredCompaniesList = List.from(_model.companiesList);
          _model.isLoading = false;
        });
      } else {
        setState(() {
          _model.isLoading = false;
        });
        _showError('No se pudieron cargar las empresas');
      }
    } catch (e) {
      setState(() {
        _model.isLoading = false;
      });
      _showError('Error al cargar empresas: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _filterCompanies(String query) {
    if (query.isEmpty) {
      setState(() {
        _model.filteredCompaniesList = List.from(_model.companiesList);
      });
    } else {
      setState(() {
        _model.filteredCompaniesList = _model.companiesList.where((company) {
          final companyName =
              getJsonField(company, r'''$.name_company''').toString().toLowerCase();
          final companyNit =
              getJsonField(company, r'''$.nit''').toString().toLowerCase();
          return companyName.contains(query.toLowerCase()) ||
              companyNit.contains(query.toLowerCase());
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
            Color(0xFF003420),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    'Selecciona tu Empresa',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Elige la empresa para continuar',
                    style: TextStyle(fontFamily: 'Roboto',
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  // Search field
                  TextFormField(
                    controller: _model.textController,
                    focusNode: _model.textFieldFocusNode,
                    onChanged: _filterCompanies,
                    style: const TextStyle(fontFamily: 'Roboto',
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Buscar empresa...',
                      hintStyle: TextStyle(fontFamily: 'Roboto',
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF00a86b),
                        size: 22,
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF00a86b),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Companies grid
            Expanded(
              child: _model.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00a86b),
                        ),
                      ),
                    )
                  : _model.filteredCompaniesList.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron empresas',
                            style: TextStyle(fontFamily: 'Roboto',
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: _model.filteredCompaniesList.length,
                          itemBuilder: (context, index) {
                            final company =
                                _model.filteredCompaniesList[index];
                            final companyName = getJsonField(
                              company,
                              r'''$.name_company''',
                            ).toString();
                            final companyNit = getJsonField(
                              company,
                              r'''$.nit''',
                            ).toString();

                            return InkWell(
                              onTap: () async {
                                final selectedCompany =
                                    CompaniesStruct.maybeFromMap(company);
                                if (selectedCompany != null) {
                                  await widget.onCompanySelected(
                                      selectedCompany);
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF1E293B).withValues(alpha: 0.8),
                                      const Color(0xFF003420).withValues(alpha: 0.6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF00a86b).withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00a86b).withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF003420),
                                              Color(0xFF00a86b),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.business,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Flexible(
                                        child: Text(
                                          companyName,
                                          style: const TextStyle(fontFamily: 'Roboto',
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'NIT: $companyNit',
                                        style: TextStyle(fontFamily: 'Roboto',
                                          fontSize: 10,
                                          color: Colors.white.withValues(alpha: 0.6),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
