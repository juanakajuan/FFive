extension ExerciseCatalog {
    /// Built-in templates, grouped by emphasis and ordered by days per week inside each group, women's
    /// whole-body versions right after the standard ones.
    public static let templates: [ProgramTemplate] =
        wholeBodyTemplates + womenTemplates + upperBodyTemplates + lowerBodyTemplates + glutesAndAbsTemplates
        + chestAndTricepsTemplates + backAndBicepsTemplates + chestAndBackTemplates + armsAndShouldersTemplates
        + timeSaverTemplates
}
